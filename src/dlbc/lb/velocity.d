// Written in the D programming language.

/**
   Velocity properties of population fields.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.lb.velocity;

import dlbc.fields.field;
import dlbc.lb.connectivity;
import dlbc.lb.density;
import dlbc.lb.mask;

import dlbc.range;

/**
   Calculates the local raw velocity of a population \(\vec{n}\): \(\vec{u}(\vec{n}) = \frac{\sum_r n_r \vec{c}__r}{\rho_0(\vec{n})}\).

   Params:
     population = population vector \(\vec{n}\)
     density = if the density \(\rho_0\) has been pre-calculated, it can be passed directly
     conn = connectivity

   Returns:
     local raw velocity \(\vec{u}(\vec{n})\)
 
   Todo:
     get rid of the alias
*/
auto rawVelocity(alias conn, T)(in ref T population, in double density) @safe pure nothrow @nogc if ( isMatchingPopulation!(T,conn)) {
  immutable cv = conn.velocities;

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
auto rawVelocity(alias conn, T)(in ref T population) @safe pure nothrow @nogc if ( isMatchingPopulation!(T,conn)) {
  immutable density = population.density();
  return rawVelocity!conn(population, density);
}

/// Ditto
alias velocity = rawVelocity;

unittest {
  // Test velocity calculation.
  double[d3q19.q] pop = [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  auto den = density(pop);
  auto vel = rawVelocity!d3q19(pop);
  assert(vel == [1,1,0]);

  pop = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];

  den = density(pop);
  vel = rawVelocity!d3q19(pop, den);
  assert(den == 0.5);
  assert(vel == [-0.2,-0.2,0.2]);
}

/**
   Calculates the raw velocity at every site of a field and stores it either in a pre-allocated field, or returns a new one.

   Params:
     field = field of population vectors
     mask = mask field

   Returns:
     raw velocity field

   Todo:
     get rid of the alias
*/
auto rawVelocityField(T, U)(in ref T field, in ref U mask) if ( isPopulationField!T && isMatchingMaskField!(U,T) ) {
  alias conn = field.conn;
  auto rawVelocity = VectorFieldOf!T(field.lengths);
  assert(haveCompatibleLengthsH(field, mask, rawVelocity));

  foreach(immutable p, pop; field.arr) {
    if ( isFluid(mask[p]) ) {
      rawVelocity[p] = pop.rawVelocity!conn();
    }
    else {
      rawVelocity[p] = 0.0;
    }
  }
  return rawVelocity;
}

/// Ditto
void rawVelocityField(T, U, V)(in ref T field, in ref U mask, ref V rawVelocity) if ( isPopulationField!T && isMatchingMaskField!(U,T) && isMatchingVectorField!(V,T) ) {
  assert(haveCompatibleLengthsH(field, mask, rawVelocity));
  alias conn = field.conn;
  foreach(immutable p, pop; field.arr) {
    if ( isFluid(mask[p] ) ) {
      rawVelocity[p] = pop.rawVelocity!conn();
    }
    else {
      rawVelocity[p] = 0.0;
    }
  }
}

/// Ditto
alias velocityField = rawVelocityField;

unittest {
  // Test raw velocity field.
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

  auto rawVelocity1 = rawVelocityField(field, mask);
  assert(rawVelocity1[1,2,3] == [-0.2,-0.2, 0.2]);
  assert(isNaN(rawVelocity1[0,1,3][0]));
  assert(isNaN(rawVelocity1[0,1,3][1]));
  assert(isNaN(rawVelocity1[0,1,3][2]));

  auto rawVelocity2 = VectorFieldOf!(typeof(field))(lengths);
  rawVelocityField(field, mask, rawVelocity2);
  assert(rawVelocity2[1,2,3] == [-0.2,-0.2, 0.2]);
  assert(isNaN(rawVelocity2[0,1,3][0]));
  assert(isNaN(rawVelocity2[0,1,3][1]));
  assert(isNaN(rawVelocity2[0,1,3][2]));

  // Zero velocity on solid sites, even when it would have been NaN otherwise.
  mask[1,2,3] = Mask.Solid;
  mask[0,1,3] = Mask.Solid;
  rawVelocity1 = rawVelocityField(field, mask);
  assert(rawVelocity1[1,2,3] == [ 0.0, 0.0, 0.0]);
  assert(rawVelocity1[0,1,3] == [ 0.0, 0.0, 0.0]);
  rawVelocityField(field, mask, rawVelocity2);
  assert(rawVelocity2[1,2,3] == [ 0.0, 0.0, 0.0]);
  assert(rawVelocity2[0,1,3] == [ 0.0, 0.0, 0.0]);
}

/**
   Calculates the local velocity of a population \(\vec{n}\), corrected for
   any force contributions:
   \(\vec{u}(\vec{n}) = \frac{\sum_r n_r \vec{c}__r}{\rho_0(\vec{n})} + \frac{\tau \vec{F}}{\rho_0(\vec{n})} \)

   Params:
     population = population vector \(\vec{n}\)
     density = if the density \(\rho_0\) has been pre-calculated, it can be passed directly
     conn = connectivity
     force = force acting on the site
     tau = relaxation time of the fluid

   Returns:
     local velocity \(\vec{u}(\vec{n})\)
*/
auto correctedVelocity(alias conn, T)(in ref T population, in double density, in double[conn.d] force, in double tau) @safe pure nothrow @nogc if ( isMatchingPopulation!(T,conn) ){
  immutable cv = conn.velocities;

  double[conn.d] vel = rawVelocity!conn(population);
  foreach(immutable i; Iota!(0, conn.d) ) {
    vel[i] += tau * force[i] / density;
  }
  return vel;
}

/// Ditto
auto correctedVelocity(alias conn, T)(in ref T population, in double[conn.d] force, in double tau) @safe pure nothrow @nogc if ( isMatchingPopulation!(T,conn)) {
  immutable density = population.density();
  return correctedVelocity!conn(population, density, force, tau);
}


unittest {
  // Test velocity calculation.
  double[d3q19.q] pop = [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  auto den = density(pop);
  assert(den == 0.1);
  auto rawVel = rawVelocity!d3q19(pop);
  assert(rawVel == [1,1,0]);
  auto corrVel = correctedVelocity!d3q19(pop, [ 0.0, 0.0, 0.0 ], 1.0);
  assert(rawVel[] == corrVel[]);

  corrVel = correctedVelocity!d3q19(pop, [ 0.2, -0.2, 0.0 ], 0.5);
  assert(corrVel[] == [ 2.0, 0.0, 0.0 ]);

  pop = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];
  den = density(pop);
  assert(den == 0.5);
  rawVel = rawVelocity!d3q19(pop, den);
  assert(rawVel == [-0.2,-0.2,0.2]);
  corrVel = correctedVelocity!d3q19(pop, [ 0.0, 0.0, 0.0 ], 10000.0);
  assert(rawVel[] == corrVel[]);
  corrVel = correctedVelocity!d3q19(pop, [ 0.05, 0.05, -0.05 ], 2.0);
  assert(corrVel[] == [ 0.0, 0.0, 0.0 ]);
}

/**
   Calculates the corrected velocity at every site of a field and stores it either in a pre-allocated field, or returns a new one.

   Params:
     field = field of population vectors
     mask = mask field
     force = force field
     tau = relaxation time of the fluid

   Returns:
     corrected velocity field
*/
auto correctedVelocityField(T, U, V)(in ref T field, in ref U mask, in ref V force, in double tau) if ( isPopulationField!T && isMatchingMaskField!(U,T) && isMatchingVectorField!(V,T) ) {
  alias conn = field.conn;
  auto correctedVelocity = VectorFieldOf!T(field.lengths);
  assert(haveCompatibleLengthsH(field, mask, correctedVelocity, force));

  foreach(immutable p, pop; field.arr) {
    if ( isFluid(mask[p]) ) {
      correctedVelocity[p] = pop.correctedVelocity!conn(force[p], tau);
    }
    else {
      correctedVelocity[p] = 0.0;
    }
  }
  return correctedVelocity;
}

/// Ditto
void correctedVelocityField(T, U, V)(in ref T field, in ref U mask, ref V correctedVelocity, in ref V force, in double tau) if ( isPopulationField!T && isMatchingMaskField!(U,T) && isMatchingVectorField!(V,T) ) {
  assert(haveCompatibleLengthsH(field, mask, correctedVelocity, force));
  alias conn = field.conn;
  foreach(immutable p, pop; field.arr) {
    if ( isFluid(mask[p] ) ) {
      correctedVelocity[p] = pop.correctedVelocity!conn(force[p], tau);
    }
    else {
      correctedVelocity[p] = 0.0;
    }
  }
}

unittest {
  // Test corrected velocity field.
  import dlbc.fields.init;
  import std.math: isNaN;

  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  auto force = VectorFieldOf!(typeof(field))(lengths);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  double[d3q19.q] pop1 = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];

  field.initConst(0);
  field[1,2,3] = pop1;
  force.initConst(0);

  auto corrVelocity1 = correctedVelocityField(field, mask, force, 1.0);
  assert(corrVelocity1[1,2,3] == [-0.2,-0.2, 0.2]);
  assert(isNaN(corrVelocity1[0,1,3][0]));
  assert(isNaN(corrVelocity1[0,1,3][1]));
  assert(isNaN(corrVelocity1[0,1,3][2]));

  auto corrVelocity2 = VectorFieldOf!(typeof(field))(lengths);
  correctedVelocityField(field, mask, corrVelocity2, force, 1.0);
  assert(corrVelocity2[1,2,3] == [-0.2,-0.2, 0.2]);
  assert(isNaN(corrVelocity2[0,1,3][0]));
  assert(isNaN(corrVelocity2[0,1,3][1]));
  assert(isNaN(corrVelocity2[0,1,3][2]));

  // Zero velocity on solid sites, even when it would have been NaN otherwise.
  mask[1,2,3] = Mask.Solid;
  mask[0,1,3] = Mask.Solid;
  corrVelocity1 = correctedVelocityField(field, mask, force, 1.0);
  assert(corrVelocity1[1,2,3] == [ 0.0, 0.0, 0.0]);
  assert(corrVelocity1[0,1,3] == [ 0.0, 0.0, 0.0]);
  correctedVelocityField(field, mask, corrVelocity2, force, 1.0);
  assert(corrVelocity2[1,2,3] == [ 0.0, 0.0, 0.0]);
  assert(corrVelocity2[0,1,3] == [ 0.0, 0.0, 0.0]);
}

