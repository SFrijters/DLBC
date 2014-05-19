// Written in the D programming language.

/**
Functions that handle (parallel) output to disk.

Copyright: Stefan Frijters 2011-2014

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.io.io;

import std.datetime;

import dlbc.logging;
import dlbc.io.hdf5;

/**
   File format of the output.
*/
@("param") FileFormat outputFormat;
/**
   Name of the simulation, to be used in file names for the output.
*/
@("param") string simulationName;
/**
   Relative path to create output files at.
*/
@("param") string outputPath = ".";
/**
   Id of the simulation, based on the time it was started.
   Initialized in the static constructor of the module.
   To be used in file names for the output.
*/
string simulationId;

/**
   Possible file format options.
*/
enum FileFormat {
  /**
     Plain text ascii.
  */
  Ascii,
  /**
     (Parallel) HDF5.
  */
  HDF5,
}

/**
   The module constructor sets the unique id before main() is run.
*/
static this() {
  simulationId = Clock.currTime().toISOString();
}

void broadcastSimulationId() {
  import dlbc.parallel: MpiBcastString;
  MpiBcastString(simulationId);
  writeLogI("The name of the simulation is `%s' and its id is `%s'.", simulationName, simulationId);
}

void checkPaths() {
  outputPath.isValidPath();
}

bool isValidPath(const string path) {
  import std.file;
  if ( path.exists() ) {
    if (! isDir(path) ){
      writeLogW("Path `%s' is not a directory. I/O will probably fail.", path);
      return false;
    }
  }
  else {
    writeLogW("Path `%s' does not exist. I/O will probably fail.", path);
    return false;
  }
  return true;
}

string makeFilenameOutput(FileFormat fileFormat)(const string name) {
  import std.string;
  static if ( fileFormat == FileFormat.Ascii ) {
    immutable string ext = "asc";
  }
  else static if ( fileFormat == FileFormat.HDF5 ) {
    immutable string ext = "h5";
  }
  else {
    static assert(0, "File name extension not specified for this file format.");
  }
  return format("%s/%s-%s-%s.%s", outputPath, name, simulationName, simulationId, ext);
}

