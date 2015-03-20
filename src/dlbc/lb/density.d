// Written in the D programming language.

/**
   Density and mass properties of population fields.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.lb.density;

import dlbc.lb.advection: postAdvectionHooks;
import dlbc.lb.connectivity;
import dlbc.fields.field;
import dlbc.lb.mask;
import dlbc.lb.force;
import dlbc.lattice: isLattice;

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
auto density(T)(in ref T population) @safe pure nothrow @nogc {
  import std.algorithm;
  return sum(population[]);
  /++
  import dlbc.range;
  BaseElementType!T sum = 0.0;
  foreach(immutable vq; Iota!(0,LengthOf!T) ) {
    sum += population[vq];
  }
  return sum;
  ++/
}

unittest {
  // Test density calculations.
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

   Todo:
     add proper template constraint to the second form of the function instead of the static assert; dmd v2.066.0 segfaults.
*/
auto densityField(T, U)(in ref T field, in ref U mask) if (isPopulationField!T && isMatchingMaskField!(U,T) ) {
  alias conn = field.conn;

  auto density = ScalarFieldOf!T(field.lengths);
  assert(haveCompatibleLengthsH(field, mask, density));

  foreach(immutable p, pop; field.arr) {
    density[p] = pop.density();
  }
  return density;
}

/// Ditto
void densityField(T, U, V)(in ref T field, in ref U mask, ref V density) if (isPopulationField!T && isMaskField!U && isMatchingScalarField!(V,T) ) {
  static assert(haveCompatibleDims!(field, mask, density));
  assert(haveCompatibleLengthsH(field, mask, density));

  foreach(immutable p, pop; field.arr) {
    density[p] = pop.density();
  }
}

unittest {
  // Test density field calculations.
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
  assert(approxEqual(density1[1,2,3], 0.5 ));
  assert(approxEqual(density1[2,0,1], 1.9 ));
  assert(approxEqual(density1[0,1,3], 0.0 ));

  auto density2 = ScalarFieldOf!(typeof(field))(lengths);
  densityField(field, mask, density2);
  assert(approxEqual(density2[1,2,3], 0.5 ));
  assert(approxEqual(density2[2,0,1], 1.9 ));
  assert(approxEqual(density2[0,1,3], 0.0 ));
}

/**
   Calculates the total mass of a population field on the local process only.

   Params:
     field = population field
     mask = mask field

   Returns:
     total mass of the field on the local process
*/
auto localTotalMass(T, U)(in ref T field, in ref U mask) if (isPopulationField!T && isMatchingMaskField!(U,T) ) {
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

unittest {
  // Test local total mass calculation.
  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  field.initConst(0.1);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  auto mass = field.localTotalMass(mask);

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
auto globalTotalMass(T, U)(in ref T field, in ref U mask) if (isPopulationField!T && isMatchingMaskField!(U,T) ) {
  assert(haveCompatibleLengthsH(field, mask));

  import dlbc.parallel;
  auto localTotalMass = localTotalMass(field, mask);
  typeof(localTotalMass) globalTotalMass;
  MPI_Allreduce(&localTotalMass, &globalTotalMass, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  return globalTotalMass;
}

unittest {
  // Test global total mass calculation.
  startMpi(M, []);
  reorderMpi(M, nc);

  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  field.initConst(0.1);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  auto mass = field.globalTotalMass(mask);

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
auto localAverageDensity(T, U)(in ref T field, in ref U mask) if (isPopulationField!T && isMatchingMaskField!(U,T) ) {
  return localTotalMass(field, mask) / field.size;
}

unittest {
  // Test local average density.
  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  field.initConst(0.1);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  auto density = localAverageDensity(field, mask);

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
auto globalAverageDensity(T, U)(in ref T field, in ref U mask) if (isPopulationField!T && isMatchingMaskField!(U,T) ) {
  import dlbc.parallel;
  return globalTotalMass(field, mask) / ( field.size * M.size);
}

unittest {
  // Test global average density.
  startMpi(M, []);
  reorderMpi(M, nc);

  size_t[d3q19.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
  field.initConst(0.1);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  auto density = globalAverageDensity(field, mask);

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
auto colourField(T, U)(in ref T field1, in ref T field2, in ref U mask) if (isPopulationField!T && isMatchingMaskField!(U,T) ) {
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
void colourField(T, U, V)(in ref T field1, in ref T field2, in ref U mask, ref V colour ) if (isPopulationField!T && isMatchingMaskField!(U,T) && isMatchingScalarField!(V,T) ) {
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
auto pressure(alias conn, T)(in ref T[] density) {
  final switch(psiForm) {
    case PsiForm.Linear:
      return density.pressurePsi!(PsiForm.Linear, conn)();
    case PsiForm.Exponential:
      return density.pressurePsi!(PsiForm.Exponential, conn)();
  }
}

/// Ditto
private auto pressurePsi(PsiForm form, alias conn, T)(in ref T[] density) {
  import dlbc.lb.force;
  double pressure = 0.0;
  foreach(immutable i, d1; density) {
    pressure += d1;
    foreach(immutable j, d2; density) {
      pressure += 0.5*gcc[i][j]*psi!form(d1)*psi!form(d2);
    }
  }
  return (pressure * conn.css);
}

/**
   Initialize the pre-calculated density field array and the fields themselves.
*/
void prepareDensityFields(T)(ref T L) if ( isLattice!T ) {
  assert(L.density.length == 0);
  L.density.length = L.fluids.length;
  foreach(immutable f; 0..L.density.length ) {
    L.density[f] = typeof(L.density[f])(L.lengths);
  }
  // Advection will make the density fields stale.
  postAdvectionHooks.registerFunction(&markDensitiesAsStale!T);
}

/**
   Fills the lattice density arrays by recomputing the values from the populations.
*/
void precalculateDensities(T)(ref T L) if ( isLattice!T ) {
  assert(L.density.length == L.fluids.length);
  foreach(immutable f; 0..L.fluids.length ) {
    if ( L.density[f].isStale ) {
      L.fluids[f].densityField(L.mask, L.density[f]);
      L.density[f].markAsFresh();
    }
  }
}

/**
   Mark all density fields on the lattice as invalid.
*/
void markDensitiesAsStale(T)(ref T L) if ( isLattice!T ) {
  assert(L.density.length == L.fluids.length);
  foreach(immutable f; 0..L.fluids.length ) {
    L.density[f].markAsStale();
  }
}


