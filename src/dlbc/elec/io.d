// Written in the D programming language.

/**
   Functions that handle output for elec modules.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.elec.io;

/**
   Frequency at which electric charge fields should be written to disk.
*/
@("param") int elecQFreq;
/**
   Frequency at which electric potentials should be written to disk.
*/
@("param") int elecPotFreq;
/**
   Frequency at which dielectric constants should be written to disk.
*/
@("param") int elecDielFreq;
/**
   Frequency at which electric fields should be written to disk.
*/
@("param") int elecFieldFreq;

import dlbc.elec.elec;
import dlbc.io.io;
import dlbc.lattice;

/**
   Dump elec data to disk, based on the current lattice and the current timestep.

   Params:
     L = current lattice
     t = current timestep
*/
void dumpElecData(T)(ref T L, uint t) if ( isLattice!T ) {
  if ( ! enableElec ) return;

  if ( dumpNow(elecQFreq,t) ) {
    L.elQp.dumpField("elQp", t);
    L.elQn.dumpField("elQn", t);
  }

  if ( dumpNow(elecPotFreq,t) ) {
    L.elPot.dumpField("elPot", t);
  }

  if ( dumpNow(elecDielFreq,t) ) {
    L.elDiel.dumpField("elDiel", t);
  }

  if ( dumpNow(elecFieldFreq,t) ) {
    L.elField.dumpField("elField", t);
  }
}

