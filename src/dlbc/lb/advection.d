// Written in the D programming language.

/**
   Lattice Boltzmann advection for population fields.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.lb.advection;

import dlbc.lb.connectivity;
import dlbc.lb.mask;
import dlbc.fields.field;
import dlbc.range;
import dlbc.timers;

/**
   Advect a population field over one time step. The advected values are first
   stored in the $(D tempField), and at the end the fields are swapped.

   Params:
     field = field to be advected
     mask = mask field
     tempField = temporary field of the same size and type as $(D field)
*/
void advectField(T, U)(ref T field, in ref U mask, ref T tempField) if ( isPopulationField!T && isMaskField!U ) {
  import std.algorithm: swap;

  static assert(haveCompatibleDims!(field, mask, tempField));
  assert(haveCompatibleLengthsH(field, mask, tempField));

  alias conn = field.conn;

  startTimer("main.advection");

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

  stopTimer("main.advection");
}

/++
import dlbc.lattice;
void advectLattice(T)(ref T L) if ( isLattice!T ) {
  import std.algorithm: swap;

  alias conn = L.lbconn;

  if ( L.fluids.length < 1 ) return;

  startTimer("main.advection");

  immutable cv = conn.velocities;
  assert(L.fluids.length == L.advectionArr.length);
  foreach(immutable p, ref dummy; L.advectionArr[0].arr) {
    if ( p.isOnEdge!conn(L.advectionArr[0].lengthsH) ) continue;
    if ( isAdvectable(L.mask[p]) ) {
      foreach(immutable vq; Iota!(0, conn.q) ) {
        conn.vel_t nb;
        foreach(immutable vd; Iota!(0, conn.d) ) {
          nb[vd] = p[vd] - cv[vq][vd];
        }
        if ( isBounceBack(L.mask[nb]) ) {
	  foreach(immutable i; 0..L.fluids.length) {
	    L.advectionArr[i][p][vq] = L.fluids[i][p][conn.bounce[vq]];
	  }
        }
        else {
	  foreach(immutable i; 0..L.fluids.length) {
	    L.advectionArr[i][p][vq] = L.fluids[i][nb][vq];
	  }
        }
      }
    }
    else {
      foreach(immutable i; 0..L.fluids.length) {
	L.advectionArr[i][p] = L.fluids[i][p];
      }
    }
  }
  foreach(immutable i; 0..L.fluids.length) {
    swap(L.fluids[i], L.advectionArr[i]);
  }

  stopTimer("main.advection");
}
++/

bool isOnEdge(alias conn)(in ptrdiff_t[conn.d] p, in size_t[conn.d] lengthsH) @safe nothrow pure @nogc {
  import dlbc.range: Iota;
  foreach(immutable i; Iota!(0, conn.d) ) {
    if ( p[i] == 0 || p[i] == lengthsH[i] - 1 ) {
      return true;
    }
  }
  return false;
}

unittest {
  /**
     Check advection, both for fluid and solid (no advection!) nodes.
  */
  void testWithDims(alias conn)() {
    import dlbc.fields.init;
    size_t[conn.d] lengths = 8;
    size_t[conn.d] p = 2;

    auto field = Field!(double[conn.q], conn, 2)(lengths);
    auto temp = Field!(double[conn.q], conn, 2)(lengths);
    auto mask = MaskFieldOf!(typeof(field))(lengths);
    mask.initConst(Mask.None);

    double[conn.q] pop = 42;
    foreach(immutable vq; Iota!(1, conn.q - 1 ) ) {
      pop[vq] = vq;
    }

    field.initConst(0.0);
    field[p] = pop;
    field.advectField(mask, temp);

    immutable cv = conn.velocities;
    foreach(immutable vq; Iota!(0, conn.q) ) {
      conn.vel_t nb;
      foreach(immutable vd; Iota!(0, conn.d) ) {
        nb[vd] = 2 + cv[vq][vd];
      }
      if ( vq == 0 ) {
        assert(field[nb][vq] == 42);
      }
      else {
        assert(field[nb][vq] == vq);
      }
    }
 
    field[p] = pop;
    mask[p] = Mask.Solid;
    field.advectField(mask, temp);
    foreach(immutable vq; Iota!(0, conn.q) ) {
      if ( vq == 0 ) {
        assert(field[p][vq] == 42);
      }
      else {
        assert(field[p][vq] == vq);
      }
    }
  }

  testWithDims!d2q9();
  testWithDims!d3q19();
}

// Check parallel
/++
unittest {
  import dlbc.fields.init;
  import dlbc.logging;
  import dlbc.parallel;
  import dlbc.fields.parallel;

  startMpi(M, []);
  reorderMpi(M, nc);

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
    field.advectField(mask, temp);

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
++/

