module dlbc.getopt;

import dlbc.logging;
import dlbc.parparse;

import std.getopt;

/// Process CLI
void processCLI(string[] args) {
  writeLogRN("Processing command line arguments.");
  VL verbosityLevel = getGlobalVerbosityLevel();
  getopt( args,
          "p|parameterfile", &parameterFileNames,
          "v|verbose", &verbosityLevel,
          "W", &warningsAreFatal,
          );
  setGlobalVerbosityLevel(verbosityLevel);
}

