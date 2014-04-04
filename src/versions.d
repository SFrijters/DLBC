import logging;

void showRevisionInfo() {
  import revision;

  if (revisionChanged == 0) {
    writeLogRI("Executable built from revision '%s'.", revisionDesc );
  }
  else if (revisionChanged == 1) {
    writeLogRI("Executable built from revision '%s' (with local changes).", revisionDesc );
    writeLogRD("Changes from HEAD:\n%s\n", revisionChanges );
  }
  else {
    writeLogRI("Executable built from unknown revision." );
  }
}

void showCompilerInfo() {
  import std.compiler;
  import std.conv: to;

  with(std.compiler) {
    writeLogRI("Executable built using %s compiler (%s); front-end version %d.%03d.", name, to!string(vendor), version_major, version_minor );
  }
}

