// Written in the D programming language.

/**
   Lattice Boltzmann collision for population fields.
   This also includes the calculation of equilibrium distributions.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License, version 3 (GPL-3.0)).

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
import dlbc.lb.velocity;

/**
   Let the populations of the field collide.

   Params:
     field = field of populations
     conn = connectivity
*/
void collideField(alias conn, T)(ref T field) {
  enum omega = 1.0;
  foreach(ref population; field.byElementForward) { // this includes the halo
    population[] -= omega * ( population[] - (eqDist!conn(population))[]);
  }
}

/**
   Generate the third order equilibrium distribution population \(\vec{n}^{\mathrm{eq}}\) of a population \(\vec{n}\). This follows the equation \(n_i^\mathrm{eq} = \rho_0 \omega_i \left( 1 + \frac{\vec{u} \cdot \vec{c}__i}{c_s^2} + \frac{ ( \vec{u} \cdot \vec{c}__i )^2}{2 c_s^4} - \frac{\vec{u} \cdot \vec{u}}{2 c_s^2} \right) \), with \(\omega_i\) and \(\vec{c}__i\) the weights and velocity vectors of the connectivity, respectively, and \(c_s^2 = 1/3\) the lattice speed of sound squared. The mass and momentum are conserved.

   Params:
     population = population vector \(\vec{n}\)
     conn = connectivity

   Returns:
     equilibrium distribution \(\vec{n}^{\mathrm{eq}}\)
*/
auto eqDist(alias conn, T)(const ref T population) {
  import std.numeric: dotProduct;

  auto immutable cv = conn.velocities;
  auto immutable cw = conn.weights;
  static assert(population.length == cv.length);
  static assert(population.length == cw.length);

  auto immutable rho0 = population.density();
  auto immutable v = population.velocity!(conn)(rho0);
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
  population[] = 0.0;
  for ( int i = 0; i < population.length; i++ ){
    population[i] = uniform(0.0, 1.0, rng);
    eq = eqDist!d3q19(population);
    assert(approxEqual(eq.density(), population.density()));                  // Mass conservation
    assert(approxEqual(eq.velocity!(d3q19)[],population.velocity!(d3q19)[])); // Momentum conservation
  }
}

