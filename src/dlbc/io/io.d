// Written in the D programming language.

/**
   Functions that handle (parallel) output to disk.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.io.io;

import std.datetime;

import dlbc.elec.io;
import dlbc.fields.field;
import dlbc.lb.density;
import dlbc.lb.io;
import dlbc.lattice;
import dlbc.logging;
import dlbc.io.checkpoint;
import dlbc.io.hdf5;
import dlbc.parameters;
import dlbc.timers;

/**
   Completely enable / disable IO.
*/
@("param") bool enableIO = true;
/**
   Name of the simulation, to be used in file names for the output.
   This string can contain tokens of the form %module.parameter%,
   or even %module.parameter[i]% - these will be replaced with the
   value of the parameter.
*/
@("param") string simulationName;
/**
   File format of the output.
*/
@("param") FileFormat outputFormat = FileFormat.HDF5;
/**
   Relative path to create output files at.
*/
@("param") string outputPath = ".";
/**
   Whether or not to create directories if necessary.
*/
@("param") bool createPath = true;
/**
   From which timestep to start writing files.
*/
@("param") int startOutput;

/**
   Id of the simulation, based on the time it was started.
   Initialized in broadcastSimulationId.
   To be used in file names for the output.
*/
string simulationId;

/**
   Flag to remember if we have synchronized a simulation id.
*/
bool simulationIdIsBcast = false;

/**
   Indentifier for checkpoint to restore from.
*/
string restoreString;

/**
   Possible file format options.
*/
enum FileFormat {
  /**
     (Parallel) HDF5.
  */
  HDF5,
  /**
     Plain text ascii.
  */
  Ascii,
}

/**
   Ensure that the simulationId is globally the same, by broadcasting the value
   from the root process. This function should be called early in the simulation,
   but definitely before any IO has been performed.

   This function also replaces tokens in $(D simulationName) and broadcasts the result.
*/
void initSimulationId() {
  import dlbc.parallel: MpiBcastString;
  simulationId = Clock.currTime().toISOString()[0..15];
  MpiBcastString(simulationId);
  simulationIdIsBcast = true;
  simulationName = simulationName.replaceFnameTokens();
  MpiBcastString(simulationName);
  writeLogRI("The name of the simulation is `%s' and its id is `%s'.", simulationName, simulationId);
  outputPath = outputPath.replaceFnameTokens();
  MpiBcastString(outputPath);
  writeLogRI("The output path is `%s'.", outputPath);
}

/**
   Give early warnings about problems with various paths that may be used later.
*/
void checkPaths() {
  if ( ! enableIO ) return;
  import dlbc.parallel: M;
  if (M.isRoot() ) {
    string[] paths = [ outputPath, outputPath~"/"~cpPath ];
    foreach(path; paths) {
      path.isValidPath();
    }
  }
}

/**
   Check whether a string represents a valid path: it should exist and be a directory.
   This function should only be used by root.

   Params:
     path = path to check
*/
bool isValidPath(in string path) {
  import std.file;
  if ( path.exists() && path.isDir() ) {
    return true;
  }

  if ( path.exists() && !path.isDir() ) {
    writeLogRW("Path `%s' exists, but is not a directory. I/O will probably fail.", path);
    return false;
  }

  if ( createPath ) {
    writeLogRI("Path `%s' does not exist - creating directory.", path);
    mkdirRecurse(path);
  }
  else {
    writeLogRW("Path `%s' is not a directory. I/O will probably fail.", path);
  }
  return false;
}

/**
   Creates a filename based on the file format (which determines the extension),
   the global parameters $(D outputPath) and $(D simulationName) and the automatically
   generated $(D simulationId). A custom name can be supplied, which will be prepended.

   Params:
     name = name of the field, to be prepended to the file name
     time = current timestep
*/
string makeFilenameOutput(FileFormat fileFormat)(in string name, in int time) {
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
  return format("%s/%s-%s-%s-t%08d.%s", outputPath, name, simulationName, simulationId, time, ext);
}

/**
   Attempt to remove a file, if it exists.

   Params:
     fileName = file to remove
*/
void removeFile(in string fileName) {
  import dlbc.parallel: M;
  import std.file;
  if ( M.isRoot() ) {
    if ( fileName.exists() ) {
      writeLogRI("Removing file '%s'.", fileName);
      fileName.remove();
    }
  }
}

/**
   Dump data to disk, based on the current lattice and the current timestep.

   Params:
     L = current lattice
     t = current timestep
*/
void dumpData(T)(ref T L, int t) if ( isLattice!T ) {
  if ( ! enableIO || t < startOutput ) {
    return;
  }

  writeLogRN("Dumping data.");

  // Checkpointing has its own routine.
  if (dumpNow(cpFreq,t)) {
    dumpCheckpoint(L, t);
    removeCheckpoint(L, t - (cpFreq * cpKeep));
  }

  L.dumpLBData(t);
  L.dumpElecData(t);

}

/**
   Data should be dumped if the frequency is larger than zero, and if the
   current timestep is a multiple of the frequency.

   Params:
     freq = dumping frequency
     t = current timestep
*/
bool dumpNow(uint freq, int t) @safe pure nothrow @nogc {
  return ( freq > 0 && ( t % freq == 0 ) );
}

/**
   Wrapper function to write a field to disk.
   Depending on the value of $(D outputFormat) the matching
   output function will be called.

   Params:
     field = field to be written
     name = name of the field, to be used in the file name
     time = current timestep
*/
void dumpField(T)(ref T field, in string name, in int time = 0) if (isField!T) {
  startTimer("io.out");
  final switch(outputFormat) {
  case FileFormat.Ascii:
    assert(0, "Ascii dumping of fields not yet implemented.");
  case FileFormat.HDF5:
    dumpFieldHDF5(field, name, time);
    break;
  }
  stopTimer("io.out");
}

/**
   Wrapper function to read a field from disk.
   Depending on the value of $(D outputFormat) the matching
   reading function will be called.

   Params:
     field = field to be read
     fileName = name of the file
*/
void readField(T)(ref T field, in string fileName) if (isField!T) {
  startTimer("io.in");
  final switch(outputFormat) {
  case FileFormat.Ascii:
    assert(0, "Ascii reading of fields not yet implemented.");
  case FileFormat.HDF5:
    readFieldHDF5(field, fileName);
    break;
  }
  stopTimer("io.in");
}
