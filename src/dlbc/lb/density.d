// Written in the D programming language.

/**
   Density and mass properties of population fields.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.density;

import dlbc.lb.connectivity;
import dlbc.fields.field;
import dlbc.lb.mask;

version(unittest) {
  import dlbc.fields.init;
  import dlbc.parallel;
  import std.math: approxEqual;
}

/**
   Calculates the local density of a population \(\vec{n}\): \(\rho_0(\vec{n}) = \sum_r n_r\).

   Params:
     population = population vector \(\vec{n}\)

   Returns:
     local density \(\rho_0(\vec{n})\)
*/
auto density(T)(const ref T population) {
  import std.algorithm;
  return sum(population[]);
}

///
unittest {
  double[d3q19.q] pop = [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  auto den = density(pop);
  assert(den == 0.1);

  pop = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];
  den = density(pop);
  assert(den == 0.5);
}

/**
   Calculates the density at every site of a field and stores it either in a pre-allocated field, or returns a new one.

   Params:
     field = field of population vectors
     mask = mask field

   Returns:
     density field
*/
auto densityField(T, U)(const ref T field, const ref U mask) if (isPopulationField!T && isMaskField!U ) {
  static assert(haveCompatibleDims!(field, mask));

  alias conn = field.conn;

  auto density = ScalarFieldOf!T(field.lengths);
  assert(haveCompatibleLengthsH(field, mask, density));

  foreach(immutable p, pop; field.arr) {
    density[p] = pop.density();
  }
  return density;
}

/// Ditto
void densityField(T, U, V)(const ref T field, const ref U mask, ref V density) if (isPopulationField!T && isMaskField!U && isMatchingScalarField!(V,T) ) {
  static assert(haveCompatibleDims!(field, mask, density));
  assert(haveCompatibleLengthsH(field, mask, density));

  foreach(immutable p, pop; field.arr) {
    density[p] = pop.density();
  }
}

///
unittest {
  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  double[d3q19.q] pop1 = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];
  double[d3q19.q] pop2 = [ 1.0, 0.0, -0.1, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.8, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];

  field.initConst(0);
  field[1,2,3] = pop1;
  field[2,0,1] = pop2;

  auto density1 = densityField(field, mask);
  assert(density1[1,2,3] == 0.5);
  assert(density1[2,0,1] == 1.9);
  assert(density1[0,1,3] == 0.0);

  auto density2 = ScalarFieldOf!(typeof(field))(lengths);
  densityField(field, mask, density2);
  assert(density2[1,2,3] == 0.5);
  assert(density2[2,0,1] == 1.9);
  assert(density2[0,1,3] == 0.0);
}

/**
   Calculates the total mass of a population field on the local process only.

   Params:
     field = population field
     mask = mask field

   Returns:
     total mass of the field on the local process
*/
auto localMass(T, U)(const ref T field, const ref U mask) if (isPopulationField!T && isMaskField!U ) {
  static assert(haveCompatibleDims!(field, mask));
  assert(haveCompatibleLengthsH(field, mask));

  double mass = 0.0;
  // This loops over the physical field only.
  foreach(immutable p, pop; field) {
    if ( isFluid(mask[p])) {
      mass += pop.density();
    }
  }
  return mass;
}

///
unittest {
  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  field.initConst(0.1);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  auto mass = field.localMass(mask);

  assert(approxEqual(mass,d3q19.q*4*4*4*0.1));
}

/**
   Calculates the global mass of a population field.

   Params:
     field = population field
     mask = mask field

   Returns:
     global mass of the field
*/
auto globalMass(T, U)(const ref T field, const ref U mask) if (isPopulationField!T && isMaskField!U ) {
  static assert(haveCompatibleDims!(field, mask));
  assert(haveCompatibleLengthsH(field, mask));

  import dlbc.parallel;
  auto localMass = localMass(field, mask);
  typeof(localMass) globalMass;
  MPI_Allreduce(&localMass, &globalMass, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  return globalMass;
}

///
unittest {
  startMpi(M, []);
  reorderMpi(M, nc);

  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  field.initConst(0.1);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  auto mass = field.globalMass(mask);

  assert(approxEqual(mass,M.size*d3q19.q*4*4*4*0.1));
}

/**
   Calculates the average density of a population field on the local process only.

   Params:
     field = population field
     mask = mask field

   Returns:
     average density of the field on the local process
*/
auto localDensity(T, U)(const ref T field, const ref U mask) if (isPopulationField!T && isMaskField!U ) {
  return localMass(field, mask) / field.size;
}

///
unittest {
  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  field.initConst(0.1);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  auto density = localDensity(field, mask);

  assert(approxEqual(density,d3q19.q*0.1));
}

/**
   Calculates the global average density of a population field.

   Params:
     field = population field
     mask = mask field

   Returns:
     global average density of the field
*/
auto globalDensity(T, U)(const ref T field, const ref U mask) if (isPopulationField!T && isMaskField!U ) {
  import dlbc.parallel;
  return globalMass(field, mask) / ( field.size * M.size);
}

///
unittest {
  startMpi(M, []);
  reorderMpi(M, nc);

  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  field.initConst(0.1);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  auto density = globalDensity(field, mask);

  assert(approxEqual(density,d3q19.q*0.1));
}

/**
   Calculates the density difference between two fields at every site and stores it either in a pre-allocated field, or returns a new one.

   Params:
     field1 = field of population vectors
     field2 = field of population vectors
     mask = mask field

   Returns:
     colour field
*/
auto colourField(T, U)(const ref T field1, const ref T field2, const ref U mask) if (isPopulationField!T && isMaskField!U ) {
  static assert(haveCompatibleDims!(field1, field2, mask));
  alias conn = field1.conn;
  auto colour = Field!(double, conn, field1.haloSize)(field1.lengths);
  assert(haveCompatibleLengthsH(field1, field2, mask, colour));

  foreach(immutable p, ref pop; field1.arr) {
    if ( isFluid(mask[p]) ) {
      colour[p] = field1[p].density() - field2[p].density();
    }
    else {
      colour[p] = 0.0;
    }
  }
  return colour;
}

/// Ditto
void colourField(T, U, V)(const ref T field1, const ref T field2, const ref U mask, ref V colour ) if (isPopulationField!T && isMaskField!U && isMatchingScalarField!(V,T) ) {
  static assert(haveCompatibleDims!(field1, field2, mask, colour));
  assert(haveCompatibleLengthsH(field1, field2, mask, colour));

  foreach(immutable p, pop; field1.arr) {
    if ( isFluid(mask[p]) ) {
      colour[p] = field1[p].density() - field2[p].density();
    }
    else {
      colour[p] = 0.0;
    }
  }
}

/**
   Calculates the local pressure of an array of densities: \(P = \sum \rho_c c_s^2 + \frac{c_s^2}{2} \sum g_{c c'} \Psi_c \Psi_{c'}\).

   Params:
     density = array of densities \(\rho_c\) for the different components

   Returns:
     local pressure \(P\)
*/
auto pressure(alias conn, T)(const ref T density[]) {
  import std.algorithm;
  import dlbc.lb.force;
  double pressure = 0.0;
  foreach(immutable i, d1; density) {
    pressure += d1;
    foreach(immutable j, d2; density) {
      pressure += 0.5*gccm[i][j]*psi(d1)*psi(d2);
    }
  }
  return (pressure * conn.css);
}

