// Written in the D programming language.

/**
   Helper functions for testing the code.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

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

