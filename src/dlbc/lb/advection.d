// Written in the D programming language.

/**
   Lattice Boltzmann advection for population fields.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.lb.advection;

import dlbc.lattice: isLattice;
import dlbc.lb.connectivity;
import dlbc.lb.mask;
import dlbc.fields.field;
import dlbc.range;
import dlbc.timers;

/**
   Advect the LB population fields over one time step. The advected values are first
   stored in a temporary field, and at the end the fields are swapped.

   Params:
     L = lattice
*/

void advectFields(T)(ref T L) if ( isLattice!T ) {
  if ( L.fluids.length == 0 ) return;

  startTimer("main.advection");

  L.advectFieldsKernel();

  stopTimer("main.advection");
}

// Ditto
private void advectFieldsKernel(T)(ref T L) if ( isLattice!T ) {
  import std.algorithm: swap;
  alias conn = L.lbconn;

  immutable cv = conn.velocities;
  foreach(immutable f; 0..L.fluids.length) {
    foreach(immutable p, ref pop; L.advection.arr) {
      if ( isOnEdge!conn(p, L.advection.lengthsH ) ) continue;
      if ( isAdvectable(L.mask[p]) ) {
	foreach(immutable vq, ref e; pop ) {
	  conn.vel_t nb;
	  foreach(immutable vd; Iota!(0, conn.d) ) {
	    nb[vd] = p[vd] - cv[vq][vd];
	  }
	  if ( isBounceBack(L.mask[nb]) ) {
	    e = L.fluids[f][p][conn.bounce[vq]];
	  }
	  else {
	    e = L.fluids[f][nb][vq];
	  }
	}
      }
      else {
	pop = L.fluids[f][p];
      }
    }
    swap(L.fluids[f], L.advection);
  }
}

bool isOnEdge(alias conn)(in ptrdiff_t[conn.d] p, in size_t[conn.d] lengthsH) @safe nothrow pure @nogc {
  import dlbc.range: Iota;
  foreach(immutable i; Iota!(0, conn.d) ) {
    if ( p[i] == 0 || p[i] == lengthsH[i] - 1 ) {
      return true;
    }
  }
  return false;
}

