// Written in the D programming language.

/**
   Momentum properties of population fields.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.momentum;

import dlbc.fields.field;
import dlbc.lb.bc;
import dlbc.lb.connectivity;
import dlbc.lb.density;
import dlbc.lb.velocity;

/**
   Calculates the local momentum of a population \(\vec{n}\): \(\vec{p}(\vec{n}) = \sum_r n_r \vec{c}__r\).

   Params:
     population = population vector \(\vec{n}\)
     conn = connectivity

   Returns:
     local momentum \(\vec{p}(\vec{n})\)
*/
auto momentum(alias conn, T)(const ref T population) {
  auto immutable cv = conn.velocities;
  static assert(population.length == cv.length);

  double[conn.dimensions] momentum;
  momentum[] = 0.0;
  foreach(i, e; population) {
    momentum[0] += e * cv[i][0];
    momentum[1] += e * cv[i][1];
    momentum[2] += e * cv[i][2];
  }
  return momentum;
}

/**
   Calculates the momentum at every site of a field and stores it either in a pre-allocated field, or returns a new one.

   Params:
     field = field of population vectors
     mask = mask field
     momentum = pre-allocated momentum field

   Returns:
     momentum field
*/
auto momentumField(alias conn, T, U)(ref T field, ref U mask) {
  static assert(is(U.type == BoundaryCondition ) );
  static assert(field.dimensions == mask.dimensions);
  assert(field.lengthsH == mask.lengthsH);

  auto momentum = Field!(double[conn.dimensions], field.dimensions, field.haloSize)(field.lengthsH);
  foreach(x,y,z, ref population; field.arr) {
    if ( isFluid(mask[x,y,z]) ) {
      momentum[x,y,z] = population.momentum!conn();
    }
    else {
      momentum[x,y,z][] = 0.0;
    }
  }
  return momentum;
}

/// Ditto
void momentumField(alias conn, T, U, V)(ref T field, ref U mask, ref V momentum) {
  static assert(is(U.type == BoundaryCondition ) );
  static assert(field.dimensions == mask.dimensions);
  static assert(field.dimensions == momentum.dimensions);
  assert(field.lengthsH == mask.lengthsH);
  assert(field.lengthsH == momentum.lengthsH);

  foreach(x,y,z, ref population; field.arr) {
    if ( isFluid(mask[x,y,z]) ) {
      momentum[x,y,z] = population.momentum!conn();
    }
    else {
      momentum[x,y,z][] = 0.0;
    }
  }
}

/**
   Calculates the total momentum of a population field on the local process only.

   Params:
     field = population field
     mask = mask field

   Returns:
     total momentum of the field on the local process
*/
auto localMomentum(alias conn, T, U)(ref T field, ref U mask) {
  static assert(is(U.type == BoundaryCondition ) );
  static assert(field.dimensions == mask.dimensions);
  assert(field.lengthsH == mask.lengthsH);

  double[conn.dimensions] momentum = 0.0;
  foreach(x, y, z, ref e; field) {
    if ( isFluid(mask[x,y,z]) ) {
      momentum[] += e.momentum!conn()[];
    }
  }
  return momentum;
}

/**
   Calculates the global momentum of a population field.

   Params:
     field = population field
     mask = mask field

   Returns:
     global momentum of the field
*/
auto globalMomentum(alias conn, T, U)(ref T field, ref U mask) {
  static assert(is(U.type == BoundaryCondition ) );
  static assert(field.dimensions == mask.dimensions);
  assert(field.lengthsH == mask.lengthsH);

  import dlbc.parallel;
  auto localMomentum = field.localMomentum!conn(mask);
  typeof(localMomentum) globalMomentum;
  MPI_Allreduce(&localMomentum, &globalMomentum, conn.dimensions, MPI_DOUBLE, MPI_SUM, M.comm);
  return globalMomentum;
}

