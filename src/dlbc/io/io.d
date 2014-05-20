// Written in the D programming language.

/**
   Functions that handle (parallel) output to disk.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

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
import dlbc.timers;

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

private bool simulationIdIsBcast = false;

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

/**
   Ensure that the simulationId is globally the same, by broadcasting the value
   from the root process. This function should be called early in the simulation,
   but definitely before any IO has been performed.
*/
void broadcastSimulationId() {
  import dlbc.parallel: MpiBcastString;
  MpiBcastString(simulationId);
  writeLogRI("The name of the simulation is `%s' and its id is `%s'.", simulationName, simulationId);
  simulationIdIsBcast = true;
}

/**
   Give early warnings about problems with various paths that may be used later.
*/
void checkPaths() {
  outputPath.isValidPath();
}

/**
   Check whether a string represents a valid path: it should exist and be a directory.

   Params:
     path = path to check
*/
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

/**
   Creates a filename based on the file format (which determines the extension),
   the global parameters $(D outputPath) and $(D simulationName) and the automatically
   generated $(D simulationId). A custom name can be supplied, which will be prepended.

   Params:
     name = name of the field, to be prepended to the file name
*/
string makeFilenameOutput(FileFormat fileFormat)(const string name, const uint time) {
  import std.string;

  assert( simulationIdIsBcast, "Do not attempt to create a file name without first calling broadcastSimulationId() once.");

  static if ( fileFormat == FileFormat.Ascii ) {
    immutable string ext = "asc";
  }
  else static if ( fileFormat == FileFormat.HDF5 ) {
    immutable string ext = "h5";
  }
  else {
    static assert(0, "File name extension not specified for this file format.");
  }
  return format("%s/%s-%s-t%08d-%s.%s", outputPath, name, simulationName, time, simulationId, ext);
}

/**
   Wrapper function to write a field to disk using HDF5.
   Depending on the value of $(D outputFormat) the matching
   output function will be called.

   Params:
     field = field to be written
     name = name of the field, to be used in the file name
*/
void dumpField(T)(ref T field, const string name, const uint time = 0) {
  Timers.io.start();
  final switch(outputFormat) {
  case FileFormat.Ascii:
    assert(0, "Ascii dumping of fields not yet implemented.");
  case FileFormat.HDF5:
    dumpFieldHDF5(field, name, time);
    break;
  }
  Timers.io.stop();
}

