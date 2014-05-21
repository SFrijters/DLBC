// Written in the D programming language.

/**
   Lattice Boltzmann advection for population fields.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.advection;

import dlbc.lb.bc;
import dlbc.lb.connectivity;
import dlbc.fields.field;
import dlbc.timers;

/**
   Advect a population field over one time step. The advected values are first
   stored in the $(D tempField), and at the end the fields are swapped.

   Params:
     field = field to be advected
     mask = mask field
     tempField = temporary field of the same size and type as $(D field)
     conn = connectivity
*/
void advectField(alias conn, T, U)(ref T field, ref U mask, ref T tempField) {
  import std.algorithm: swap;

  static assert(is(U.type == BoundaryCondition ) );
  static assert(field.dimensions == mask.dimensions);
  static assert(field.dimensions == tempField.dimensions);
  assert(mask.lengthsH == field.lengthsH, "mask and advected field need to have the same size");
  assert(tempField.lengthsH == field.lengthsH, "tempField and advected field need to have the same size");

  Timers.adv.start();

  auto immutable cv = conn.velocities;
  foreach( x, y, z, ref population; tempField) {
    if ( isAdvectable(mask[x,y,z]) ) {
      assert(population.length == cv.length);
      foreach( i, ref c; population ) {
	auto nbx = x-cv[i][0];
	auto nby = y-cv[i][1];
	auto nbz = z-cv[i][2];
	if ( isBounceBack(mask[nbx,nby,nbz]) ) {
	  c = field[x, y, z][conn.bounce[i]];
	}
	else {
	  c = field[nbx, nby, nbz][i];
      	}
      }
    }
    else {
      population = field[x, y, z];
    }
  }
  swap(field, tempField);

  Timers.adv.stop();
}

///
unittest {
  import dlbc.fields.init;
  import dlbc.logging;
  import dlbc.parallel;
  import dlbc.fields.parallel;

  startMpi([]);
  reorderMpi();

  if ( M.size == 8 ) {
    size_t[d3q19.dimensions] lengths = [ 16, 16 ,16 ];
    auto field = Field!(double[19], d3q19.dimensions, 2)(lengths);
    auto temp = Field!(double[19], d3q19.dimensions, 2)(lengths);
    auto mask = Field!(BoundaryCondition, d3q19.dimensions, 2)(lengths);

    field.initConst(0);
    if ( M.isRoot ) {
      field[2,2,2] = [42, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 ,15, 16 ,17 ,18];
    }
    field.exchangeHalo();
    mask.initConst(BC.None);
    mask.exchangeHalo();
    field.advectField!d3q19(mask, temp);

    if ( M.rank == 0 ) {
      assert(field[2,2,2][0] == 42);
      assert(field[3,2,2][1] == 1);
      assert(field[2,3,2][3] == 3);
      assert(field[2,2,3][5] == 5);
      assert(field[3,3,2][7] == 7);
      assert(field[2,3,3][9] == 9);
      assert(field[3,2,3][11] == 11);
    }
    else if ( M.rank == 1 ) {
      assert(field[2,2,17][6] == 6);
      assert(field[3,2,17][12] == 12);
      assert(field[2,3,17][15] == 15);
    }
    else if ( M.rank == 2 ) {
      assert(field[2,17,2][4] == 4);
      assert(field[2,17,3][10] == 10);
      assert(field[3,17,2][13] == 13);
    }
    else if ( M.rank == 3 ) {
      assert(field[2,17,17][16] == 16);
    }
    else if ( M.rank == 4 ) {
      assert(field[17,2,2][2] == 2);
      assert(field[17,3,2][8] == 8);
    }
    else if ( M.rank == 5) {
      assert(field[17,2,17][18] == 18);
    }
    else if ( M.rank == 6 ) {
      assert(field[17,17,2][14] == 14);
    }
  }
  else {
    writeLogURW("Unittest for advection requires M.size == 8.");
  }
}

