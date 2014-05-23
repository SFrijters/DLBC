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

import dlbc.lattice;
import dlbc.logging;

@("param") double[] globalAcc;

void initForce(alias conn, T)(ref T L) {
  if ( globalAcc.length == 0 ) {
    globalAcc.length = conn.d;
    globalAcc[] = 0.0;
  }
  else if ( globalAcc.length != conn.d ) {
    writeLogF("Array variable lb.force.globalAcc must have length %d.", conn.d);
  }

  resetForce(L);
}

void resetForce(T)(ref T L) {
  foreach(ref e; L.force.byElementForward ) {
    e[] = 0.0;
  }
}

