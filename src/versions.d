import std.compiler;
import std.conv;

import logging;
import revision;

void showRevisionInfo() {
  if (revisionChanges.length == 0) {
    writeLogRI("Executable built from revision '%s'.", revisionNumber );
  }
  else {
    writeLogRI("Executable built from revision '%s' (with local changes).", revisionNumber );
    writeLogRD("  Changes from HEAD: %s.\n", revisionChanges );
  }
}

void showCompilerInfo() {
  with(std.compiler) {
    writeLogRD("Executable built using %s compiler (%s); front-end version %d.%03d.", name, to!string(vendor), version_major, version_minor );
  }
}

