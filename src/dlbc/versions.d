// Written in the D programming language.

/**
   Functions that show information on compiler versions and code revision.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

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
    writeLog!(vl, logRankFormat)("Executable built from revision '%s', branch '%s'.", revisionDesc, revisionBranch );
  }
  else if (revisionChanged == 1) {
    writeLog!(vl, logRankFormat)("Executable built from revision '%s', branch '%s' (with local changes).", revisionDesc, revisionBranch );
    writeLog!(VL.Debug, logRankFormat)("Changes from HEAD:\n%s\n", revisionChanges );
  }
  else {
    writeLog!(vl, logRankFormat)("Executable built from unknown revision." );
  }
  version (D_Coverage) {
    writeLog!(vl, logRankFormat)("  Code coverage analysis instrumentation is being generated." );
  }
  version (D_Ddoc) {
    writeLog!(vl, logRankFormat)("  DDoc documentation is being generated." );
  }
  version (D_NoBoundsChecks) {
    writeLog!(vl, logRankFormat)("  Array bounds checks are disabled." );
  }
  version (unittest) {
    writeLog!(vl, logRankFormat)("  Unit tests are enabled." );
  }
  debug {
    writeLog!(vl, logRankFormat)("  Debug mode is enabled." );
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
