// Written in the D programming language.

/**
   Lattice Boltzmann advection for population fields.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License, version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.advection;

import dlbc.lb.connectivity;
import dlbc.fields.field;

/**
   Advect a population field over one time step. The advected values are first
   stored in the $(D tempField), and at the end the fields are swapped.

   Params:
     field = field to be advected
     tempField = temporary field of the same size and type as $(D field)
     conn = connectivity
*/
void advectField(alias conn, T)(ref T field, ref T tempField) {
  import std.algorithm: swap;

  static assert(field.dimensions == tempField.dimensions);
  auto immutable cv = conn.velocities;
  foreach( z, y, x, ref population; tempField) {
    assert(population.length == cv.length);
    foreach( i, ref c; population ) {
      c = field[z-cv[i][2], y-cv[i][1], x-cv[i][0]][i];
    }
  }
  swap(field, tempField);
}

///
unittest {
  import dlbc.fields.init;
  import dlbc.logging;
  import dlbc.parallel;

  startMpi([]);
  reorderMpi();

  if ( M.size == 8 ) {
    uint[d3q19.dimensions] lengths = [ 16, 16 ,16 ];
    auto field = Field!(double[19], d3q19.dimensions, 2)(lengths);
    auto temp = Field!(double[19], d3q19.dimensions, 2)(lengths);

    field.initConst(0);
    if ( M.isRoot ) {
      field[2,2,2] = [42, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 ,15, 16 ,17 ,18];
    }
    field.exchangeHalo();
    field.advectField!d3q19(temp);

    if ( M.rank == 0 ) {
      assert(field[2,2,2][0] == 42);
      assert(field[2,2,3][1] == 1);
      assert(field[2,3,2][3] == 3);
      assert(field[3,2,2][5] == 5);
      assert(field[2,3,3][7] == 7);
      assert(field[3,3,2][9] == 9);
      assert(field[3,2,3][11] == 11);
    }
    else if ( M.rank == 1 ) {
      assert(field[2,2,17][2] == 2);
      assert(field[2,3,17][8] == 8);
    }
    else if ( M.rank == 2 ) {
      assert(field[2,17,2][4] == 4);
      assert(field[3,17,2][10] == 10);
      assert(field[2,17,3][13] == 13);
    }
    else if ( M.rank == 3 ) {
      assert(field[2,17,17][14] == 14);
    }
    else if ( M.rank == 4 ) {
      assert(field[17,2,2][6] == 6);
      assert(field[17,2,3][12] == 12);
      assert(field[17,3,2][15] == 15);
    }
    else if ( M.rank == 5) {
      assert(field[17,2,17][18] == 18);
    }
    else if ( M.rank == 6) {
      assert(field[17,17,2][16] == 16);
    }
  }
  else {
    writeLogURW("Unittest for advection requires M.size == 8.");
  }
}

