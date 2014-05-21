// Written in the D programming language.

/**
   Velocity properties of population fields.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.velocity;

import dlbc.fields.field;
import dlbc.lb.connectivity;
import dlbc.lb.density;

/**
   Calculates the local velocity of a population \(\vec{n}\): \(\vec{u}(\vec{n}) = \frac{\sum_r n_r \vec{c}__r}{\rho_0(\vec{n})}\).

   Params:
     population = population vector \(\vec{n}\)
     density = if the density \(\rho_0\) has been pre-calculated, it can be passed directly
     conn = connectivity

   Returns:
     local velocity \(\vec{u}(\vec{n})\)
*/
auto velocity(alias conn, T)(const ref T population, const double density) {
  auto immutable cv = conn.velocities;
  static assert(population.length == cv.length);

  double[conn.dimensions] vel = 0.0;
  foreach(i, e; population) {
    vel[0] += e * cv[i][0];
    vel[1] += e * cv[i][1];
    vel[2] += e * cv[i][2];
  }
  vel[0] /= density;
  vel[1] /= density;
  vel[2] /= density;
  return vel;
}

/// Ditto
auto velocity(alias conn, T)(const ref T population) {
  auto immutable density = population.density();
  return velocity!conn(population, density);
}

///
unittest {
  double[d3q19.nvelocities] pop = [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  auto den = density(pop);
  auto vel = velocity!d3q19(pop);
  assert(vel == [1,1,0]);

  pop = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];

  den = density(pop);
  vel = velocity!d3q19(pop, den);
  assert(den == 0.5);
  assert(vel == [-0.2,-0.2,0.2]);
}

/**
   Calculates the velocity at every site of a field and stores it either in a pre-allocated field, or returns a new one.

   Params:
     field = field of population vectors
     velocity = pre-allocated velocity field

   Returns:
     velocity field
*/
auto velocityField(alias conn, T)(ref T field) {
  auto velocity = Field!(double[conn.dimensions], field.dimensions, field.haloSize)([field.nxH, field.nyH, field.nzH]);
  foreach(z,y,x, ref pop; field.arr) {
    velocity[z,y,x] = pop.velocity!conn();
  }
  return velocity;
}

/// Ditto
void velocityField(alias conn, T, U)(ref T field, ref U velocity) {
  static assert(field.dimensions == velocity.dimensions);
  assert(field.lengths == velocity.lengths);
  foreach(z,y,x, ref pop; field.arr) {
    velocity[z,y,x] = pop.velocity!conn;
  }
}

///
unittest {
  import dlbc.fields.init;
  import std.math: isNaN;

  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], 3, 2)(lengths);

  double[19] pop1 = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];

  field.initConst(0);
  field[1,2,3] = pop1;

  auto velocity1 = velocityField!d3q19(field);
  assert(velocity1[1,2,3] == [-0.2,-0.2, 0.2]);
  assert(isNaN(velocity1[0,1,3][0]));
  assert(isNaN(velocity1[0,1,3][1]));
  assert(isNaN(velocity1[0,1,3][2]));

  auto velocity2 = Field!(double[3], 3, 2)(lengths);
  velocityField!d3q19(field, velocity2);
  assert(isNaN(velocity2[0,1,3][0]));
  assert(isNaN(velocity2[0,1,3][1]));
  assert(isNaN(velocity2[0,1,3][2]));
}

