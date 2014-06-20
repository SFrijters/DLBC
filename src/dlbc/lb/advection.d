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

import dlbc.lb.connectivity;
import dlbc.lb.mask;
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
void advectField(alias conn, T, U)(ref T field, const ref U mask, ref T tempField) if ( isField!T && is(U.type == Mask) ) {
  import std.algorithm: swap;
  import dlbc.range: Iota;

  static assert(haveCompatibleDims!(field, mask, tempField));
  assert(haveCompatibleLengthsH(field, mask, tempField));

  Timers.adv.start();

  immutable cv = conn.velocities;
  foreach(immutable p, ref pop; tempField.arr) {
    if ( p.isOnEdge!conn(field.lengthsH) ) continue;
    if ( isAdvectable(mask[p]) ) {
      assert(pop.length == cv.length);
      foreach(immutable i, ref e; pop ) {
        conn.vel_t nb;
	foreach(immutable j; Iota!(0, conn.d) ) {
	  nb[j] = p[j] - cv[i][j];
	}
	if ( isBounceBack(mask[nb]) ) {
	  e = field[p][conn.bounce[i]];
	}
	else {
	  e = field[nb][i];
      	}
      }
    }
    else {
      pop = field[p];
    }
  }
  swap(field, tempField);

  Timers.adv.stop();
}

bool isOnEdge(alias conn)(const ptrdiff_t[conn.d] p, const size_t[conn.d] lengthsH) @safe nothrow pure {
  import dlbc.range: Iota;
  foreach(immutable i; Iota!(0, conn.d) ) {
    if ( p[i] == 0 || p[i] == lengthsH[i] - 1 ) {
      return true;
    }
  }
  return false;
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
    size_t[d3q19.d] lengths = [ 16, 16 ,16 ];
    auto field = Field!(double[d3q19.q], d3q19, 2)(lengths);
    auto temp = Field!(double[d3q19.q], d3q19, 2)(lengths);
    auto mask = Field!(Mask, d3q19, 2)(lengths);

    field.initConst(0);
    if ( M.isRoot ) {
      field[2,2,2] = [42, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 ,15, 16 ,17 ,18];
    }
    field.exchangeHalo();
    mask.initConst(Mask.None);
    mask.exchangeHalo();
    field.advectField!gconn(mask, temp);

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

