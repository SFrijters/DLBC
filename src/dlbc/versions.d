// Written in the D programming language.

/**
   Functions that show information on compiler versions and code revision.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License, version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.versions;

import dlbc.logging;


/**
   Write info on the revision of DLBC to stdout, depending on the verbosity level
   and which processes are allowed to write.

   Params:
     vl = verbosity level to write at
     logRankFormat = which processes should write
*/
void showRevisionInfo(VL vl, LRF logRankFormat)() {
  import dlbc.revision;

  if (revisionChanged == 0) {
    writeLog!(vl, logRankFormat)("Executable built from revision '%s'.", revisionDesc );
  }
  else if (revisionChanged == 1) {
    writeLog!(vl, logRankFormat)("Executable built from revision '%s' (with local changes).", revisionDesc );
    writeLog!(VL.Debug, logRankFormat)("Changes from HEAD:\n%s\n", revisionChanges );
  }
  else {
    writeLog!(vl, logRankFormat)("Executable built from unknown revision." );
  }
}

/**
   Write info on the compiler used to compile DLBC, depending on the verbosity level
   and which processes are allowed to write.

   Params:
     vl = verbosity level to write at
     logRankFormat = which processes should write
*/
void showCompilerInfo(VL vl, LRF logRankFormat)() {
  import std.compiler;
  import std.conv: to;

  with(std.compiler) {
    writeLog!(vl, logRankFormat)("Executable built using %s compiler (%s); front-end version %d.%03d.", name, to!string(vendor), version_major, version_minor );
  }
}

