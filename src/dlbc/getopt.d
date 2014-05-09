module dlbc.getopt;

import std.getopt;

import dlbc.logging;
import dlbc.parameters: parameterFileNames;

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

