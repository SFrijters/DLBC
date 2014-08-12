// Written in the D programming language.

/**
   Lattice Boltzmann equilibrium distribution functions.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.eqdist;

import dlbc.lb.density;
import dlbc.lb.velocity;
import dlbc.range;

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
}

/**
   Generate an equilibrium distribution population \(\vec{n}^{\mathrm{eq}}\) of a population \(\vec{n}\).

   Params:
     population = population vector \(\vec{n}\)
     dv = velocity shift \(\Delta \vec{u}\)
     eqDistForm = form of the equilibrium distribution
     conn = connectivity

   Returns:
     equilibrium distribution \(\vec{n}^{\mathrm{eq}}\)
*/
auto eqDist(EqDistForm eqDistForm, alias conn, T)(in ref T population, in double[conn.d] dv) {
  static assert(population.length == conn.q);
  import std.numeric: dotProduct;

  immutable cv = conn.velocities;
  immutable cw = conn.weights;
  immutable css = conn.css;
  immutable rho0 = population.density();
  immutable pv = population.velocity!(conn)(rho0);

  double[conn.d] v;
  foreach(immutable vd; Iota!(0,conn.d) ) {
    v[vd] = dv[vd] + pv[vd];
  }
  immutable vdotv = v.dotProduct(v);
  T dist;

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
  else {
    static assert(0);
  }
  return dist;
}

/// Ditto
auto eqDist(alias conn, T)(in ref T population, in double[conn.d] dv) {
  final switch(eqDistForm) {
    case eqDistForm.SecondOrder:
      return eqDist!(eqDistForm.SecondOrder, conn)(population, dv);
    case eqDistForm.ThirdOrder:
      return eqDist!(eqDistForm.ThirdOrder, conn)(population, dv);
   }
}

unittest {
  // Check mass and momentum conservation of the equilibrium distributions.
  import dlbc.lb.connectivity;
  import dlbc.random;
  import std.math: approxEqual;
  import std.traits;
  double[gconn.q] population, eq;
  double[gconn.d] dv = 0.001;
  double[gconn.d] shifted;
  population[] = 0.0;

  // Check all eqDists.
  foreach(immutable edf; EnumMembers!EqDistForm) {
    foreach(immutable vq; Iota!(0,gconn.q) ) {
      population[vq] = uniform(0.0, 1.0, rng);
      eq = eqDist!(edf, gconn)(population, dv);
      assert(approxEqual(eq.density(), population.density())); // Mass conservation
      shifted[] = eq.velocity!(gconn)()[] - dv[];
      assert(approxEqual(shifted[], population.velocity!(gconn)()[])); // Momentum conservation
    }
  }

  auto eqDistFormTemp = eqDistForm;
  foreach(immutable edf; EnumMembers!EqDistForm) {
    eqDistForm = edf;
    foreach(immutable vq; Iota!(0,gconn.q) ) {
      population[vq] = uniform(0.0, 1.0, rng);
      eq = eqDist!(gconn)(population, dv);
      assert(approxEqual(eq.density(), population.density())); // Mass conservation
      shifted[] = eq.velocity!(gconn)()[] - dv[];
      assert(approxEqual(shifted[], population.velocity!(gconn)()[])); // Momentum conservation
    }
  }
  eqDistForm = eqDistFormTemp;
}

