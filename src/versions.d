import logging;

void showRevisionInfo(VL vl, LRF logRankFormat)() {
  import revision;

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

void showCompilerInfo(VL vl, LRF logRankFormat)() {
  import std.compiler;
  import std.conv: to;

  with(std.compiler) {
    writeLog!(vl, logRankFormat)("Executable built using %s compiler (%s); front-end version %d.%03d.", name, to!string(vendor), version_major, version_minor );
  }
}

