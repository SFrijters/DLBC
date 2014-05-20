// Written in the D programming language.

/**
   Momentum properties of population fields.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License, version 3 (GPL-3.0)).

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
import dlbc.lb.velocity;

/**
   Calculates the local momentum of a population \(\vec{n}\): \(\vec{p}(\vec{n}) = \frac{\sum_r n_r \vec{c}__r}\).

   Params:
     population = population vector \(\vec{n}\)
     density = if the density \(\rho_0\) has been pre-calculated, it can be passed directly
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
     momentum = pre-allocated momentum field

   Returns:
     momentum field
*/
auto momentumField(alias conn, T)(ref T field) {
  auto momentum = Field!(double[conn.dimensions], field.dimensions, field.haloSize)([field.nxH, field.nyH, field.nzH]);
  foreach(z,y,x, ref population; field.arr) {
    momentum[z,y,x] = population.momentum!conn();
  }
  return momentum;
}

/// Ditto
void momentumField(alias conn, T, U)(ref T field, ref U momentum) {
  static assert(field.dimensions == momentum.dimensions);
  assert(field.lengths == velocity.lengths);
  foreach(z,y,x, ref population; field.arr) {
    momentum[z,y,x] = population.momentum!conn;
  }
}

/**
   Calculates the total momentum of a population field on the local process only.
   
   Params:
     field = population field

   Returns:
     total momentum of the field on the local process
*/
auto localMomentum(alias conn, T)(ref T field) {
  double[conn.dimensions] momentum = 0.0;
  foreach(z, y, x, ref e; field) {
    auto p = e.momentum!conn();
    momentum[0] += p[0];
    momentum[1] += p[1];
    momentum[2] += p[2];
  }
  return momentum;
}

/**
   Calculates the global momentum of a population field.

   Params:
     field = population field

   Returns:
     global momentum of the field
*/
auto globalMomentum(alias conn, T)(ref T field) {
  import dlbc.parallel;
  auto localMomentum = field.localMomentum!conn();
  typeof(localMomentum) globalMomentum;
  MPI_Allreduce(&localMomentum, &globalMomentum, conn.dimensions, MPI_DOUBLE, MPI_SUM, M.comm);
  return globalMomentum;
}

