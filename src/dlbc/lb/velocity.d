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
import dlbc.lb.mask;

import dlbc.range;

/**
   Calculates the local velocity of a population \(\vec{n}\): \(\vec{u}(\vec{n}) = \frac{\sum_r n_r \vec{c}__r}{\rho_0(\vec{n})}\).

   Params:
     population = population vector \(\vec{n}\)
     density = if the density \(\rho_0\) has been pre-calculated, it can be passed directly
     conn = connectivity

   Returns:
     local velocity \(\vec{u}(\vec{n})\)
*/
auto velocity(alias conn, T)(in ref T population, in double density) {
  immutable cv = conn.velocities;
  static assert(population.length == cv.length);

  double[conn.d] vel = 0.0;
  foreach(immutable i, e; population) {
    foreach(immutable j; Iota!(0, conn.d) ) {
      vel[j] += e * cv[i][j];
    }
  }
  vel[] /= density;
  return vel;
}

/// Ditto
auto velocity(alias conn, T)(in ref T population) {
  immutable density = population.density();
  return velocity!conn(population, density);
}

///
unittest {
  double[d3q19.q] pop = [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
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
     mask = mask field

   Returns:
     velocity field
*/
auto velocityField(T, U)(in ref T field, in ref U mask) if ( isPopulationField!T && isMaskField!U ) {
  static assert(haveCompatibleDims!(field, mask));
  alias conn = field.conn;
  auto velocity = VectorFieldOf!T(field.lengths);
  assert(haveCompatibleLengthsH(field, mask, velocity));

  foreach(immutable p, pop; field.arr) {
    if ( isFluid(mask[p]) ) {
      velocity[p] = pop.velocity!conn();
    }
    else {
      velocity[p] = 0.0;
    }
  }
  return velocity;
}

/// Ditto
void velocityField(T, U, V)(in ref T field, in ref U mask, ref V velocity) if ( isPopulationField!T && isMaskField!U && isMatchingVectorField!(V,T) ) {
  static assert(haveCompatibleDims!(field, mask, velocity));
  assert(haveCompatibleLengthsH(field, mask, velocity));
  alias conn = field.conn;
  foreach(immutable p, pop; field.arr) {
    if ( isFluid(mask[p] ) ) {
      velocity[p] = pop.velocity!conn();
    }
    else {
      velocity[p] = 0.0;
    }
  }
}

///
unittest {
  import dlbc.fields.init;
  import std.math: isNaN;

  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  double[d3q19.q] pop1 = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];

  field.initConst(0);
  field[1,2,3] = pop1;

  auto velocity1 = velocityField(field, mask);
  assert(velocity1[1,2,3] == [-0.2,-0.2, 0.2]);
  assert(isNaN(velocity1[0,1,3][0]));
  assert(isNaN(velocity1[0,1,3][1]));
  assert(isNaN(velocity1[0,1,3][2]));

  auto velocity2 = VectorFieldOf!(typeof(field))(lengths);
  velocityField(field, mask, velocity2);
  assert(velocity2[1,2,3] == [-0.2,-0.2, 0.2]);
  assert(isNaN(velocity2[0,1,3][0]));
  assert(isNaN(velocity2[0,1,3][1]));
  assert(isNaN(velocity2[0,1,3][2]));

  // Zero velocity on solid sites.
  mask[1,2,3] = Mask.Solid;
  velocity1 = velocityField(field, mask);
  assert(velocity1[1,2,3] == [ 0.0, 0.0, 0.0]);
  velocityField(field, mask, velocity2);
  assert(velocity2[1,2,3] == [ 0.0, 0.0, 0.0]);

}

