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

import dlbc.fields.field;
import dlbc.lb.mask;

version(unittest) {
  import dlbc.lb.connectivity;
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
  double[19] pop = [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
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
     density = pre-allocated density field

   Returns:
     density field
*/
auto densityField(T, U)(ref T field, ref U mask) {
  static assert(is(U.type == Mask ) );
  static assert(field.dimensions == mask.dimensions);
  assert(field.lengthsH == mask.lengthsH);

  auto density = Field!(double, field.dimensions, field.haloSize)(field.lengthsH);
  foreach(x,y,z, ref pop; field.arr) {
    if ( isFluid(mask[x,y,z]) ) {
      density[x,y,z] = pop.density();
    }
    else {
      density[x,y,z] = 0.0;
    }
  }
  return density;
}

/// Ditto
void densityField(T, U, V)(ref T field, ref U mask, ref V density) {
  static assert(is(U.type == Mask ) );
  static assert(field.dimensions == mask.dimensions);
  static assert(field.dimensions == density.dimensions);
  assert(field.lengthsH == mask.lengthsH);
  assert(field.lengthsH == density.lengthsH);

  foreach(x,y,z, ref pop; field.arr) {
    if ( isFluid(mask[x,y,z]) ) {
      density[x,y,z] = pop.density();
    }
    else {
      density[x,y,z] = 0.0;
    }
  }
}

///
unittest {
  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], 3, 2)(lengths);
  auto mask = Field!(Mask, d3q19.dimensions, 2)(lengths);
  mask.initConst(Mask.None);

  double[19] pop1 = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];
  double[19] pop2 = [ 1.0, 0.0, -0.1, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.8, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];

  field.initConst(0);
  field[1,2,3] = pop1;
  field[2,0,1] = pop2;

  auto density1 = densityField(field, mask);
  assert(density1[1,2,3] == 0.5);
  assert(density1[2,0,1] == 1.9);
  assert(density1[0,1,3] == 0.0);

  auto density2 = Field!(double, 3, 2)(lengths);
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
auto localMass(T, U)(ref T field, ref U mask) {
  static assert(is(U.type == Mask ) );
  static assert(field.dimensions == mask.dimensions);
  assert(field.lengthsH == mask.lengthsH);

  double mass = 0.0;
  // This loops over the physical field only.
  foreach(x, y, z, ref e; field) {
    if ( isFluid(mask[x,y,z])) {
      mass += e.density();
    }
  }
  return mass;
}

///
unittest {
  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], 3, 2)(lengths);
  field.initConst(0.1);
  auto mask = Field!(Mask, d3q19.dimensions, 2)(lengths);
  mask.initConst(Mask.None);

  auto mass = localMass(field, mask);

  assert(approxEqual(mass,19*4*4*4*0.1));
}

/**
   Calculates the global mass of a population field.

   Params:
     field = population field
     mask = mask field

   Returns:
     global mass of the field
*/
auto globalMass(T, U)(ref T field, ref U mask) {
  static assert(is(U.type == Mask ) );
  static assert(field.dimensions == mask.dimensions);
  assert(field.lengthsH == mask.lengthsH);

  import dlbc.parallel;
  auto localMass = localMass(field, mask);
  typeof(localMass) globalMass;
  MPI_Allreduce(&localMass, &globalMass, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  return globalMass;
}

///
unittest {
  startMpi([]);
  reorderMpi();

  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], d3q19.dimensions, 2)(lengths);
  field.initConst(0.1);
  auto mask = Field!(Mask, d3q19.dimensions, 2)(lengths);
  mask.initConst(Mask.None);

  auto mass = globalMass(field, mask);

  assert(approxEqual(mass,M.size*19*4*4*4*0.1));
}

/**
   Calculates the average density of a population field on the local process only.

   Params:
     field = population field
     mask = mask field

   Returns:
     average density of the field on the local process
*/
auto localDensity(T, U)(ref T field, ref U mask) {
  static assert(is(U.type == Mask ) );
  auto size = field.nx * field.ny * field.nz;
  return localMass(field, mask) / size;
}

///
unittest {
  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], d3q19.dimensions, 2)(lengths);
  field.initConst(0.1);
  auto mask = Field!(Mask, d3q19.dimensions, 2)(lengths);
  mask.initConst(Mask.None);

  auto density = localDensity(field, mask);

  assert(approxEqual(density,19*0.1));
}

/**
   Calculates the global average density of a population field.

   Params:
     field = population field
     mask = mask field

   Returns:
     global average density of the field
*/
auto globalDensity(T, U)(ref T field, ref U mask) {
  static assert(is(U.type == Mask ) );
  import dlbc.parallel;
  auto size = field.nx * field.ny * field.nz * M.size;
  return globalMass(field, mask) / size;
}

///
unittest {
  startMpi([]);
  reorderMpi();

  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], 3, 2)(lengths);
  field.initConst(0.1);
  auto mask = Field!(Mask, d3q19.dimensions, 2)(lengths);
  mask.initConst(Mask.None);

  auto density = globalDensity(field, mask);

  assert(approxEqual(density,19*0.1));
}

