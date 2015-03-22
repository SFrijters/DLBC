// Written in the D programming language.

/**
   Lattice Boltzmann equilibrium distribution functions.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.lb.eqdist;

/**
   Form of the equilibrium distribution function.
*/
@("param") EqDistForm eqDistForm;

/**
   Possible forms of the equilibrium distribution function. \(\omega_i\) and \(\vec{c}__i\) are the weights and velocity vectors of the connectivity, respectively, and \(c_s^2 = 1/3\) the lattice speed of sound squared. The velocity \(\vec{u}\) consists of the velocity of the lattice site plus a shift \(\Delta \vec{u}\) due to forces. The mass is conserved, and momentum is conserved if and only if \(\Delta \vec{u} = 0\).
*/
enum EqDistForm {
  /**
     Second order: \(n_i^\mathrm{eq} = \rho_0 \omega_i \left( 1 + \frac{\vec{u} \cdot \vec{c}__i}{c_s^2} + \frac{ ( \vec{u} \cdot \vec{c}__i )^2}{2 c_s^4} - \frac{\vec{u} \cdot \vec{u}}{2 c_s^2} \right) \).
  */
  SecondOrder,
  /**
     Third order:  \(n_i^\mathrm{eq} = \rho_0 \omega_i \left( 1 + \frac{\vec{u} \cdot \vec{c}__i}{c_s^2} + \frac{ ( \vec{u} \cdot \vec{c}__i )^2}{2 c_s^4} - \frac{\vec{u} \cdot \vec{u}}{2 c_s^2} + \frac{ ( \vec{c}__i \cdot \vec{u} )^3}{6 c_s^6} - \frac{ ( \vec{u} \cdot \vec{u} ) ( \vec{c}__i \cdot \vec{u} ) }{ 2 c_s^4} \right) \).
  */
  ThirdOrder,
  /**
     Matches bdist = 2 in LB3D code.
  */
  BDist2,
}

/**
   Generate an equilibrium distribution population \(\vec{n}^{\mathrm{eq}}\) of a population \(\vec{n}\).

   Params:
     population = population vector \(\vec{n}\)
     dv = velocity shift \(\Delta \vec{u}\)
     rho0 = density of the population (optional)
     eqDistForm = form of the equilibrium distribution
     conn = connectivity

   Returns:
     equilibrium distribution \(\vec{n}^{\mathrm{eq}}\)

   Todo:
     clean up BDist2 block; allow for connectivities other than D3Q19.
*/
auto eqDist(EqDistForm eqDistForm, alias conn, T)(in ref T population, in double[conn.d] dv) @safe pure nothrow @nogc {
  import dlbc.lb.density: density;
  immutable rho0 = population.density();
  return eqDist!(eqDistForm, conn)(population, dv, rho0);
}

/// Ditto
auto eqDist(EqDistForm eqDistForm, alias conn, T)(in ref T population, in double[conn.d] dv, in double rho0) @safe pure nothrow @nogc {
  import dlbc.lb.velocity: velocity;
  import dlbc.range: dotProduct, Iota;

  static assert(population.length == conn.q);

  T dist;

  static if ( eqDistForm == EqDistForm.SecondOrder ||
	      eqDistForm == EqDistForm.ThirdOrder ) {
    immutable cv = conn.velocities;
    immutable cw = conn.weights;
    immutable css = conn.css;
    immutable pv = population.velocity!conn(rho0);
    double[conn.d] v;
    foreach(immutable vd; Iota!(0,conn.d) ) {
      v[vd] = dv[vd] + pv[vd];
    }
    immutable vdotv = v.dotProduct(v);
  }

  static if ( eqDistForm == EqDistForm.SecondOrder ) {
    immutable css2 = 2.0 * css;
    immutable css2p2 = css2 * css;
    foreach(immutable vq; Iota!(0,conn.q)) {
      immutable vdotcv = v.dotProduct(cv[vq]);
      dist[vq] = rho0 * cw[vq] * ( 1.0 + ( vdotcv / css ) + ( vdotcv * vdotcv / css2p2 ) - ( vdotv / css2 ) );
    }
  }
  else static if ( eqDistForm == EqDistForm.ThirdOrder ) {
    immutable css2 = 2.0 * css;
    immutable css2p2 = css2 * css;
    immutable css6p3 = 3.0 * css2p2 * css;
    foreach(immutable vq; Iota!(0,conn.q)) {
      immutable vdotcv = v.dotProduct(cv[vq]);
      dist[vq] = rho0 * cw[vq] * ( 1.0 + ( vdotcv / css ) + ( vdotcv * vdotcv / css2p2 ) - ( vdotv / css2 )
        + ( vdotcv * vdotcv * vdotcv / css6p3 ) 
        - ( vdotv * vdotcv / css2p2 ) );
    }
  }
  else static if ( eqDistForm == EqDistForm.BDist2 ) {
    static if ( conn.d == 3 && conn.q == 19 ) {
      immutable aN1 = 1.0/36.0;
      immutable aN0 = 1.0/3.0;
      immutable haN1 = 0.5*aN1; // 1.0/72.0
      immutable aN1_6 = aN1/6.0; // 1.0/216.0
      immutable T = 1.0/3.0;
      immutable holdit = 1.0/T; // 3.0

      immutable tux = dv[0];
      immutable tuy = dv[1];
      immutable tuz = dv[2];

      immutable tuxt = tux*holdit;
      immutable tuyt = tuy*holdit;
      immutable tuzt = tuz*holdit;

      immutable uke = 0.5*(tux*tuxt + tuy*tuyt + tuz*tuzt);

      immutable cst = 1.0-uke;
      immutable const1 = aN1*cst;

      double cdotu, even, odd;

      cdotu = tuxt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[1] = 2.0*(even+odd); // 1 (1,0,0)
      dist[2] = 2.0*(even-odd); // 2 (-1,0,0)

      cdotu = tuyt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[3] = 2.0*(even+odd); // 3 (0,1,0)
      dist[4] = 2.0*(even-odd); // 4 (0,-1,0)

      cdotu = tuzt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[5] = 2.0*(even+odd); // 5 (0,0,1)
      dist[6] = 2.0*(even-odd); // 6 (0,0,-1)

      cdotu = tuxt+tuyt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[7] = even+odd; // 7 (1,1,0)
      dist[14] = even-odd; // 12 (-1,-1,0)

      cdotu = tuxt-tuyt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[13] = even+odd; // 8 (1,-1,0)
      dist[8] = even-odd; // 11 (-1,1,0)

      cdotu = tuxt+tuzt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[11] = even+odd; // 9 (1,0,1)
      dist[18] = even-odd; // 14 (-1,0,-1)

      cdotu = tuxt-tuzt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[12] = even+odd; // 10 (1,0,-1)
      dist[17] = even-odd; // 13 (-1,0,1)

      cdotu = tuyt+tuzt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[9] = even+odd; // 15 (0,1,1)
      dist[16] = even-odd; // 18 (0,-1,-1)

      cdotu = tuyt-tuzt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[15] = even+odd; // 16 (0,1,-1)
      dist[10] = even-odd; // 17 (0,-1,1)

      dist[0] = aN0*cst; // 19 (0,0,0)

      foreach(immutable vq; Iota!(0,conn.q)) {
	dist[vq] *= rho0;
      }
    }
    else static if ( conn.d == 2 && conn.q == 9 ) {
      immutable aN1 = 1.0/24.0;
      immutable aN0 = 1.0/2.0;
      immutable haN1 = 0.5*aN1;
      immutable aN1_6 = aN1/6.0;
      immutable T = 1.0/3.0;
      immutable holdit = 1.0/T; // 3.0

      immutable tux = dv[0];
      immutable tuy = dv[1];

      immutable tuxt = tux*holdit;
      immutable tuyt = tuy*holdit;

      immutable uke = 0.5*(tux*tuxt + tuy*tuyt);

      immutable cst = 1.0-uke;
      immutable const1 = aN1*cst;

      double cdotu, even, odd;

      cdotu = tuxt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[1] = 2.0*(even+odd); // (1,0)
      dist[2] = 2.0*(even-odd); // (-1,0)

      cdotu = tuyt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[3] = 2.0*(even+odd); // (0,1)
      dist[4] = 2.0*(even-odd); // (0,-1)

      cdotu = tuxt+tuyt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[5] = even+odd; // (1,1)
      dist[8] = even-odd; // (-1,-1)

      cdotu = tuxt-tuyt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[6] = even+odd; // (1,-1)
      dist[7] = even-odd; // (-1,1)

      dist[0] = aN0*cst; // (0,0)

      foreach(immutable vq; Iota!(0,conn.q)) {
	dist[vq] *= rho0;
      }
    }
    /++
    else static if ( conn.d == 1 && conn.q == 3 ) {
      immutable aN1 = 1.5/24.0;
      immutable aN0 = 1.5/2.0;
      immutable haN1 = 0.5*aN1; // 1.0/72.0
      immutable aN1_6 = aN1/6.0; // 1.0/216.0
      immutable T = 1.0/3.0;
      immutable holdit = 1.0/T; // 3.0

      immutable tux = dv[0];

      immutable tuxt = tux*holdit;

      immutable uke = 0.5*(tux*tuxt);

      immutable cst = 1.0-uke;
      immutable const1 = aN1*cst;

      double cdotu, even, odd;

      cdotu = tuxt;
      even = const1+haN1*cdotu*cdotu;
      odd = const1*cdotu+aN1_6*cdotu*cdotu*cdotu;
      dist[1] = 2.0*(even+odd); // (1)
      dist[2] = 2.0*(even-odd); // (-1)

      dist[0] = aN0*cst; // (0)

      foreach(immutable vq; Iota!(0,conn.q)) {
	dist[vq] *= rho0;
      }
    }
    ++/
    else {
      dist = population; // this is currently a no-op
      // assert(0, "EqDistForm.BDist2 not implemented for D1Q3.");
    }
  }
  else {
    static assert(0, "Unknown EqDistForm.");
  }
  return dist;
}

/// Ditto
auto eqDist(alias conn, T)(in EqDistForm edf, in ref T population, in double[conn.d] dv) @safe pure nothrow @nogc {
  final switch(edf) {
    // Returns appropriately templated eqDist
    mixin(edfMixin());
  }
}

/**
   Generate final switch mixin for all eqDistForm.
*/
private string edfMixin() {
  import std.traits: EnumMembers;
  import std.conv: to;
  string mixinString;
  foreach(immutable edf; EnumMembers!EqDistForm) {
    mixinString ~= "case eqDistForm." ~ to!string(edf) ~ ":\n  return eqDist!(eqDistForm."~to!string(edf)~", conn)(population, dv);\n";
  }
  return mixinString;
}

/**
   Calculate equilibrium distribution for unity density and zero velocity.

   Params:
     edf = form of the equilibrium distribution

   Returns:
     equilibrium distribution \(\vec{n}^{\mathrm{eq}}\)
*/
auto eqDistUnity(alias conn)(in EqDistForm edf) @safe pure nothrow @nogc {
  double[conn.q] pop0 = 0.0;
  pop0[0] = 1.0;
  immutable double[conn.d] dv = 0.0;
  return eqDist!conn(edf, pop0, dv);
}

unittest {
  import dlbc.lb.connectivity: gconn;
  import dlbc.lb.density: density;
  import dlbc.lb.velocity: velocity;
  import dlbc.random;
  import dlbc.range: Iota;
  import std.math: approxEqual;
  import std.traits: EnumMembers;

  immutable double[gconn.d] dv = 0.001;
  double[gconn.q] population, eq;
  double[gconn.d] shifted;
  double[gconn.d] zeroVelocity;
  population[] = 0.0;
  zeroVelocity[] = 0.0;

  // Check all eqDists.
  foreach(immutable edf; EnumMembers!EqDistForm) {
    foreach(immutable vq; Iota!(0,gconn.q) ) {
      population[vq] = uniform(0.0, 1.0, rng);

      // Test template form of eqDist.
      eq = eqDist!(edf, gconn)(population, dv);
      assert(approxEqual(eq.density(), population.density())); // Mass conservation
      if ( edf != EqDistForm.BDist2 ) {
	shifted[] = eq.velocity!gconn()[] - dv[];
	assert(approxEqual(shifted[], population.velocity!gconn()[])); // Momentum conservation
      }

      // Test runtime form of eqDist.
      eq = eqDist!(edf, gconn)(population, dv);
      assert(approxEqual(eq.density(), population.density())); // Mass conservation
      if ( edf != EqDistForm.BDist2 ) {
	shifted[] = eq.velocity!gconn()[] - dv[];
	assert(approxEqual(shifted[], population.velocity!gconn()[])); // Momentum conservation
      }

      // Test unity eqDist.
      eq = eqDistUnity!gconn(edf);
      assert(approxEqual(eq.density(), 1.0));
      assert(eq.velocity!gconn() == zeroVelocity);
    }
  }
}

unittest {
  version(D_Coverage) {
    cast(void) edfMixin();
  }
}

