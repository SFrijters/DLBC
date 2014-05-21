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
import dlbc.lb.mask;
import dlbc.lb.velocity;
import dlbc.timers;

/**
   Let the populations of the field collide.

   Params:
     field = field of populations
     mask = mask field
     conn = connectivity
*/
void collideField(alias conn, T, U)(ref T field, ref U mask) {
  static assert(is(U.type == Mask ) );
  static assert(field.dimensions == mask.dimensions);
  assert(mask.lengthsH == field.lengthsH, "mask and collided field need to have the same size");

  Timers.coll.start();

  enum omega = 1.0;
  auto dv = [0.0, 0.0, 0.0];
  foreach(x, y, z, ref population; field.arr) { // this includes the halo
    if ( isCollidable(mask[x,y,z]) ) {
      population[] -= omega * ( population[] - (eqDist!conn(population, dv))[]);
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
auto eqDist(alias conn, T)(const ref T population, const double[] dv) {
  import std.numeric: dotProduct;

  auto immutable cv = conn.velocities;
  auto immutable cw = conn.weights;
  static assert(population.length == cv.length);
  static assert(population.length == cw.length);

  immutable auto rho0 = population.density();
  immutable auto pv = population.velocity!(conn)(rho0);
  double[conn.dimensions] v = dv[] + pv[];
  enum css = 1.0/3.0;

  auto immutable vdotv = v.dotProduct(v);

  T dist;
  foreach(i, e; cv) {
    immutable auto vdotcv = v.dotProduct(e);
    dist[i] = rho0 * cw[i] * ( 1.0 + ( vdotcv / css ) + ( (vdotcv * vdotcv ) / ( 2.0 * css * css ) ) - ( ( vdotv ) / ( 2.0 * css) ) );
  }
  return dist;
}

///
unittest {
  import dlbc.random;
  import std.math: approxEqual;
  double[d3q19.nvelocities] population, eq;
  double[d3q19.dimensions] dv = 0.0;
  population[] = 0.0;
  for ( int i = 0; i < population.length; i++ ){
    population[i] = uniform(0.0, 1.0, rng);
    eq = eqDist!d3q19(population, dv);
    assert(approxEqual(eq.density(), population.density()));                  // Mass conservation
    assert(approxEqual(eq.velocity!(d3q19)[],population.velocity!(d3q19)[])); // Momentum conservation
  }
}

