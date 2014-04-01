import logging;
import parameters;

import std.getopt; 

/// Process CLI
void processCLI(string[] args) {
  writeLogRN("Processing command line arguments.");
  VL verbosityLevel = globalVerbosityLevel;
  getopt( args,
          "p|parameterfile", &parameterFileNames,
          "v|verbose", &verbosityLevel
          );
  setGlobalVerbosityLevel(verbosityLevel);
}

