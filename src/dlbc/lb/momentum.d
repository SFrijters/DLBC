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
import dlbc.lb.connectivity;
import dlbc.lb.density;
import dlbc.lb.mask;
import dlbc.lb.velocity;
import dlbc.range;

version(unittest) {
  import dlbc.fields.init;
  import dlbc.parallel;
  import std.math: approxEqual;
}

/**
   Calculates the local momentum of a population \(\vec{n}\): \(\vec{p}(\vec{n}) = \sum_r n_r \vec{c}__r\).

   Params:
     population = population vector \(\vec{n}\)
     conn = connectivity

   Returns:
     local momentum \(\vec{p}(\vec{n})\)
*/
auto momentum(alias conn, T)(const ref T population) {
  immutable cv = conn.velocities;
  static assert(population.length == cv.length);

  double[conn.d] momentum = 0.0;
  foreach(immutable i, e; population) {
    foreach(immutable j; Iota!(0, conn.d) ) {
      momentum[j] += e * cv[i][j];
    }
  }
  return momentum;
}

/**
   Calculates the momentum at every site of a field and stores it either in a pre-allocated field, or returns a new one.

   Params:
     field = field of population vectors
     mask = mask field

   Returns:
     momentum field
*/
auto momentumField(T, U)(const ref T field, const ref U mask) if ( isPopulationField!T && isMaskField!U ) {
  static assert(haveCompatibleDims!(field, mask));
  alias conn = field.conn;
  auto momentum = VectorFieldOf!T(field.lengths);
  assert(haveCompatibleLengthsH(field, mask, momentum));

  foreach(immutable p, pop; field.arr) {
    if ( isFluid(mask[p]) ) {
      momentum[p] = pop.momentum!conn();
    }
    else {
      momentum[p] = 0.0;
    }
  }
  return momentum;
}

/// Ditto
void momentumField(T, U, V)(const ref T field, const ref U mask, ref V momentum) if ( isPopulationField!T && isMaskField!U && isMatchingVectorField!(V,T) ) {
  static assert(haveCompatibleDims!(field, mask, momentum));
  assert(haveCompatibleLengthsH(field, mask, momentum));
  alias conn = field.conn;
  foreach(immutable p, pop; field.arr) {
    if ( isFluid(mask[p]) ) {
      momentum[p] = pop.momentum!conn();
    }
    else {
      momentum[p] = 0.0;
    }
  }
}

///
unittest {
  size_t[gconn.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[gconn.q], gconn, 2)(lengths);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);

  double[gconn.q] pop1 = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];

  field.initConst(0.0);
  field[1,2,3] = pop1;

  auto momentum1 = momentumField(field, mask);
  assert(momentum1[1,2,3] == [-0.1,-0.1, 0.1]);
  assert(momentum1[0,1,3] == [0.0, 0.0, 0.0]);

  auto momentum2 = VectorFieldOf!(typeof(field))(lengths);
  momentumField(field, mask, momentum2);
  assert(momentum2[1,2,3] == [-0.1,-0.1, 0.1]);
  assert(momentum2[0,1,3] == [0.0, 0.0, 0.0]);
}

/**
   Calculates the total momentum of a population field on the local process only.

   Params:
     field = population field
     mask = mask field

   Returns:
     total momentum of the field on the local process
*/
auto localMomentum(T, U)(const ref T field, const ref U mask) if ( isPopulationField!T && isMaskField!U ) {
  static assert(haveCompatibleDims!(field, mask));
  assert(haveCompatibleLengthsH(field, mask));
  alias conn = field.conn;
  double[conn.d] momentum = 0.0;
  foreach(immutable p, pop; field) {
    if ( isFluid(mask[p]) ) {
      double[conn.d] pmomentum = pop.momentum!conn();
      foreach(immutable j; Iota!(0, conn.d) ) {
        momentum[j] += pmomentum[j];
      }
    }
  }
  return momentum;
}

///
unittest {
  size_t[gconn.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[gconn.q], gconn, 2)(lengths);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);
  double[gconn.q] pop1 = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];
  field.initConst(0.0);
  field[1,2,3] = pop1; // Inside the halo, this should not be counted!
  field[3,3,3] = pop1;

  auto momentum = localMomentum(field, mask);
  assert(momentum == [-0.1,-0.1, 0.1]);
}

/**
   Calculates the global momentum of a population field.

   Params:
     field = population field
     mask = mask field

   Returns:
     global momentum of the field
*/
auto globalMomentum(T, U)(const ref T field, const ref U mask) if ( isPopulationField!T && isMaskField!U ) {
  static assert(haveCompatibleDims!(field, mask));
  assert(haveCompatibleLengthsH(field, mask));
  alias conn = field.conn;
  import dlbc.parallel;
  auto localMomentum = field.localMomentum(mask);
  typeof(localMomentum) globalMomentum;
  MPI_Allreduce(&localMomentum, &globalMomentum, conn.d, MPI_DOUBLE, MPI_SUM, M.comm);
  return globalMomentum;
}

///
unittest {
  startMpi([]);
  reorderMpi();

  import dlbc.fields.init;

  size_t[gconn.d] lengths = [ 4, 4 ,4 ];
  auto field = Field!(double[gconn.q], gconn, 2)(lengths);
  auto mask = MaskFieldOf!(typeof(field))(lengths);
  mask.initConst(Mask.None);
  double[gconn.q] pop1 = [ 0.1, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
                     0.1, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0];
  field.initConst(0.0);
  field[1,2,3] = pop1; // Inside the halo, this should not be counted!
  field[3,3,3] = pop1;

  auto momentum = field.globalMomentum(mask);
  assert(approxEqual(momentum[0], M.size * -0.1));
  assert(approxEqual(momentum[1], M.size * -0.1));
  assert(approxEqual(momentum[2], M.size *  0.1));
}
