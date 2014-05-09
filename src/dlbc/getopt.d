module dlbc.getopt;

import dlbc.logging;
import dlbc.parameters;
import dlbc.parparse;

import std.getopt;

/// Process CLI
void processCLI(string[] args) {
  writeLogRN("Processing command line arguments.");
  VL verbosityLevel = getGlobalVerbosityLevel();
  getopt( args,
          "p|parameterfile", &dlbc.parparse.parameterFileNames,
          "v|verbose", &verbosityLevel,
          "W", &warningsAreFatal,
          );
  dlbc.parameters.parameterFileNames = dlbc.parparse.parameterFileNames;
  setGlobalVerbosityLevel(verbosityLevel);
}

