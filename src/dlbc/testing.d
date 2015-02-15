// Written in the D programming language.

/**
   Helper functions for testing the code.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.testing;

import dlbc.logging;

/**
   Minimal run for coverage testing only.
   
   Todo:
     Implement better checks for this.
*/
bool onlyCoverage = false;

void breakForCoverage() {
  import std.c.stdlib: exit;
  writeLogRI("Requested --coverage, ending run.");
  exit(0);
}

