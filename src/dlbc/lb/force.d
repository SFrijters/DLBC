// Written in the D programming language.

/**
   Lattice Boltzmann force and acceleration calculations.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.lb.force;

import dlbc.lb.density;
import dlbc.lb.mask;
import dlbc.fields.init;
import dlbc.lattice;
import dlbc.logging;

import dlbc.lb.lb;

@("param") double[] globalAcc;

@("param") double gcc = 0.0;

void initForce(alias conn, T)(ref T L) {
  if ( globalAcc.length == 0 ) {
    globalAcc.length = conn.d;
    globalAcc[] = 0.0;
  }
  else if ( globalAcc.length != conn.d ) {
    writeLogF("Array variable lb.force.globalAcc must have length %d.", conn.d);
  }

  L.resetForce();
}

void resetForce(T)(ref T L) {
  foreach( ref e; L.force) {
    e.initConst(0.0);
  }
}

void addShanChenForce(alias conn, T)(ref T L) {
  auto cv = conn.velocities;
  auto cw = conn.weights;
  double[conn.d] df;
  for( int nc1 = 0; nc1 < L.fluids.length; nc1++ ) {
    for( int nc2 = 0; nc2 < L.fluids.length; nc2++ ) { // no self-interaction
      if ( nc1 == nc2 ) continue;
      foreach( x, y, z, ref force ; L.force[nc1] ) {
	if ( isCollidable(L.mask[x,y,z]) ) {
	  auto psiden1 = psi(L.fluids[nc1][x,y,z].density());
	  foreach( i, ref c; cv ) {
	    auto nbx = x-cv[i][0];
	    auto nby = y-cv[i][1];
	    auto nbz = z-cv[i][2];
	    if ( ! isBounceBack(L.mask[nbx,nby,nbz]) ) {
	      auto psiden2 = psi(L.fluids[nc2][nbx,nby,nbz].density());
	      force[0] += psiden1 * psiden2 * gcc * cv[i][0]; // minus and minus from inverted cv
	      force[1] += psiden1 * psiden2 * gcc * cv[i][1];
	      force[2] += psiden1 * psiden2 * gcc * cv[i][2];
	    }
	  }
	}
      }
    }
  }
}

private double psi(double den) {
  import std.math;
  return ( 1.0 - exp(-den) );
}

