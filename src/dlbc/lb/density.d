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
     density = pre-allocated density field

   Returns:
     density field
*/
auto densityField(T)(ref T field) {
  auto density = Field!(double, field.dimensions, field.haloSize)([field.nxH, field.nyH, field.nzH]);
  foreach(z,y,x, ref pop; field.arr) {
    density[z,y,x] = pop.density();
  }
  return density;
}

/// Ditto
void densityField(T, U)(ref T field, ref U density) {
  static assert(field.dimensions == density.dimensions);
  assert(field.lengths == density.lengths);
  foreach(z,y,x, ref pop; field.arr) {
    density[z,y,x] = pop.density();
  }
}

///
unittest {
  import dlbc.fields.init;

  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], 3, 2)(lengths);

  double[19] pop1 = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];
  double[19] pop2 = [ 1.0, 0.0, -0.1, 0.0, 0.0, 0.0, 0.0,
  		     0.1, 0.0, 0.0, 0.8, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];

  field.initConst(0);
  field[1,2,3] = pop1;
  field[2,0,1] = pop2;
  
  auto density1 = densityField(field);
  assert(density1[1,2,3] == 0.5);
  assert(density1[2,0,1] == 1.9);
  assert(density1[0,1,3] == 0.0);

  auto density2 = Field!(double, 3, 2)(lengths);
  densityField(field, density2);
  assert(density2[1,2,3] == 0.5);
  assert(density2[2,0,1] == 1.9);
  assert(density2[0,1,3] == 0.0);
}

/**
   Calculates the total mass of a population field on the local process only.
   
   Params:
     field = population field

   Returns:
     total mass of the field on the local process
*/
auto localMass(T)(ref T field) {
  double mass = 0.0;
  // This loops over the physical field only.
  foreach(z, y, x, ref e; field) {
    mass += e.density();
  }
  return mass;
}

///
unittest {
  import dlbc.fields.init;
  import std.math: approxEqual;

  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], 3, 2)(lengths);
  field.initConst(0.1);

  auto mass = localMass(field);

  assert(approxEqual(mass,19*4*4*4*0.1));
}

/**
   Calculates the global mass of a population field.

   Params:
     field = population field

   Returns:
     global mass of the field
*/
auto globalMass(T)(ref T field) {
  import dlbc.parallel;
  auto localMass = localMass(field);
  typeof(localMass) globalMass;
  MPI_Allreduce(&localMass, &globalMass, 1, MPI_DOUBLE, MPI_SUM, M.comm);
  return globalMass;
}

///
unittest {
  import dlbc.fields.init;
  import dlbc.parallel;
  import std.math: approxEqual;

  startMpi([]);
  reorderMpi();

  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], 3, 2)(lengths);
  field.initConst(0.1);

  auto mass = globalMass(field);

  assert(approxEqual(mass,M.size*19*4*4*4*0.1));
}

/**
   Calculates the average density of a population field on the local process only.
   
   Params:
     field = population field

   Returns:
     average density of the field on the local process
*/
auto localDensity(T)(ref T field) {
  auto size = field.nx * field.ny * field.nz;
  return localMass(field) / size;
}

///
unittest {
  import dlbc.fields.init;
  import std.math: approxEqual;

  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], 3, 2)(lengths);
  field.initConst(0.1);

  auto density = localDensity(field);

  assert(approxEqual(density,19*0.1));
}

/**
   Calculates the global average density of a population field.

   Params:
     field = population field

   Returns:
     global average density of the field
*/
auto globalDensity(T)(ref T field) {
  import dlbc.parallel;
  auto size = field.nx * field.ny * field.nz * M.size;
  return globalMass(field) / size;
}

///
unittest {
  import dlbc.fields.init;
  import dlbc.parallel;
  import std.math: approxEqual;

  startMpi([]);
  reorderMpi();

  size_t[3] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[19], 3, 2)(lengths);
  field.initConst(0.1);

  auto density = globalDensity(field);

  assert(approxEqual(density,19*0.1));
}


