// Written in the D programming language.

/**
   Lattice Boltzmann collision for population fields.
   This also includes the calculation of equilibrium distributions.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.collision;

import dlbc.fields.field;
import dlbc.lb.connectivity;
import dlbc.lb.density;
import dlbc.lb.force;
import dlbc.lb.mask;
import dlbc.lb.velocity;
import dlbc.range;
import dlbc.timers;

import dlbc.logging;

/++
/**
   Let the populations of the field collide.

   Params:
     field = field of populations
     mask = mask field
     force = force field
     conn = connectivity
*/
void collideField(alias conn, T, U, V)(ref T field, ref U mask, ref V force) {
  static assert(is(U.type == Mask));
  static assert(field.dimensions == force.dimensions);
  static assert(field.dimensions == mask.dimensions);
  assert(force.lengthsH == field.lengthsH, "force field and collided field need to have the same size");
  assert(mask.lengthsH == field.lengthsH, "mask and collided field need to have the same size");
  assert(force.dimensions == conn.d, "force needs to have the same dimension as the connectivity");
  assert(globalAcc.length == conn.d, "globalAcc needs to have the same dimension as the connectivity");

  Timers.coll.start();

  enum omega = 1.0;
  foreach(x, y, z, ref population; field.arr) { // this includes the halo
    if ( isCollidable(mask[x,y,z]) ) {
      // We need this temporary variable because direct assignment is not implemented in DMD yet.
      double[conn.d] dv = globalAcc[] + force[x,y,z][] / population.density(); 
      population[] -= omega * ( population[] - (eqDist!conn(population, dv))[]);
    }
  }

  Timers.coll.stop();
}
+/

/**
   Let the populations of the field collide.

   Params:
     field = field of populations
     mask = mask field
     force = force field
     conn = connectivity
*/
void collideField(alias conn, T, U, V)(ref T field, ref U mask, ref V force) {
  static assert(is(U.type == Mask));
  static assert(field.dimensions == force.dimensions);
  static assert(field.dimensions == mask.dimensions);
  assert(force.lengthsH == field.lengthsH, "force field and collided field need to have the same size");
  assert(mask.lengthsH == field.lengthsH, "mask and collided field need to have the same size");
  assert(force.dimensions == conn.d, "force needs to have the same dimension as the connectivity");
  assert(globalAcc.length == conn.d, "globalAcc needs to have the same dimension as the connectivity");

  Timers.coll.start();

  enum omega = 1.0;
  foreach(p, ref population; field.arr) { // this includes the halo
    if ( isCollidable(mask[p]) ) {
      // We need this temporary variable because direct assignment is not implemented in DMD yet.
      double[conn.d] dv;
      //      Timers.collden.start();
      auto den = population.density();
      //      Timers.collden.stop();
      foreach(i; Iota!(0,conn.d) ) {
	dv[i] = globalAcc[i] + force[p][i] / den;
      }
      //      Timers.colleq.start();
      auto eq = eqDist!conn(population, dv);
      //      Timers.colleq.stop();
      foreach(i; Iota!(0,conn.q) ) {
	population[i] -= omega * ( population[i] - eq[i]);
      }
    }
  }

  Timers.coll.stop();
}

/**
   Generate the third order equilibrium distribution population \(\vec{n}^{\mathrm{eq}}\) of a population \(\vec{n}\). This follows the equation \(n_i^\mathrm{eq} = \rho_0 \omega_i \left( 1 + \frac{\vec{u} \cdot \vec{c}__i}{c_s^2} + \frac{ ( \vec{u} \cdot \vec{c}__i )^2}{2 c_s^4} - \frac{\vec{u} \cdot \vec{u}}{2 c_s^2} \right) \), with \(\omega_i\) and \(\vec{c}__i\) the weights and velocity vectors of the connectivity, respectively, and \(c_s^2 = 1/3\) the lattice speed of sound squared. The velocity \(\vec{u}\) consists of the velocity of the lattice site plus a shift \(\Delta \vec{u}\) due to forces. The mass is conserved, and momentum is conserved if and only if \(\Delta \vec{u} = 0\).

   Params:
     population = population vector \(\vec{n}\)
     dv = velocity shift \(\Delta \vec{u}\)
     conn = connectivity

   Returns:
     equilibrium distribution \(\vec{n}^{\mathrm{eq}}\)
*/
auto eqDist(alias conn, T)(const ref T population, const double[conn.d] dv) {
  import std.numeric: dotProduct;

  auto immutable cv = conn.velocities;
  auto immutable cw = conn.weights;
  static assert(population.length == cv.length);
  static assert(population.length == cw.length);

  immutable auto rho0 = population.density();
  immutable auto pv = population.velocity!(conn)(rho0);
  // double[conn.d] v = dv[] + pv[];

  double[conn.d] v;
  foreach(i; Iota!(0,conn.d) ) {
    v[i] = dv[i] + pv[i];
  }
  enum css = 1.0/3.0;

  auto immutable vdotv = v.dotProduct(v);
  // double vdotv2;
  // foreach(j; Iota!(0,conn.d)) {
  //   vdotv2 += v[j]*v[j];
  // }

  T dist;
  // foreach(i, e; cv) {
  //   immutable auto vdotcv = v.dotProduct(e);
  foreach(i; Iota!(0,conn.q)) {
    immutable auto vdotcv = v.dotProduct(cv[i]);
    //   double vdotcv;
    //   foreach(j; Iota!(0,conn.d)) {
    //     vdotcv += v[j]*cv[i][j];
    //   }
    dist[i] = rho0 * cw[i] * ( 1.0 + ( vdotcv / css ) + ( (vdotcv * vdotcv ) / ( 2.0 * css * css ) ) - ( ( vdotv ) / ( 2.0 * css) ) );
  }
  return dist;
}

///
unittest {
  import dlbc.random;
  import std.math: approxEqual;
  double[gconn.q] population, eq;
  double[gconn.d] dv = 0.0;
  population[] = 0.0;
  for ( size_t i = 0; i < population.length; i++ ){
    population[i] = uniform(0.0, 1.0, rng);
    eq = eqDist!gconn(population, dv);
    assert(approxEqual(eq.density(), population.density()));                  // Mass conservation
    assert(approxEqual(eq.velocity!(gconn)[],population.velocity!(gconn)[])); // Momentum conservation
  }
}

