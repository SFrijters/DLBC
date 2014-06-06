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

import dlbc.lb.lb;
import dlbc.lattice;
import dlbc.logging;
import dlbc.io.ascii;
import dlbc.io.checkpoint;
import dlbc.io.hdf5;
import dlbc.timers;

/**
   Name of the simulation, to be used in file names for the output.
*/
@("param") string simulationName;
/**
   File format of the output.
*/
@("param") FileFormat outputFormat;
/**
   Relative path to create output files at.
*/
@("param") string outputPath = ".";
/**
   Whether or not to create directories if necessary.
*/
@("param") bool createPath = false;
/**
   From which timestep to start writing files.
*/
@("param") int startOutput;
/**
   Frequency at which the velocity field should be written to disk.
*/
@("param") int velFreq;
/**
   Frequency at which profiles should be written to disk.
*/
@("param") int profileFreq;
/**
   Frequency at which fluid density fields should be written to disk.
*/
@("param") int fluidsFreq;
/**
   Frequency at which fluid density difference fields (colour) should be written to disk.
*/
@("param") int colourFreq;
/**
   Frequency at which velocity fields should be written to disk.
*/
@("param") int velocitiesFreq;
/**
   Frequency at which force fields should be written to disk.
*/
@("param") int forceFreq;
/**
   Frequency at which mask fields should be written to disk.
*/
@("param") int maskFreq;

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
     Plain text ascii.
  */
  Ascii,
  /**
     (Parallel) HDF5.
  */
  HDF5,
}

/**
   Ensure that the simulationId is globally the same, by broadcasting the value
   from the root process. This function should be called early in the simulation,
   but definitely before any IO has been performed.
*/
void initSimulationId() {
  import dlbc.parallel: MpiBcastString;
  simulationId = Clock.currTime().toISOString()[0..15];
  MpiBcastString(simulationId);
  writeLogRI("The name of the simulation is `%s' and its id is `%s'.", simulationName, simulationId);
  simulationIdIsBcast = true;
}

/**
   Give early warnings about problems with various paths that may be used later.
*/
void checkPaths() {
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

   Params:
     path = path to check
*/
bool isValidPath(const string path) {
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
  return format("%s/%s-%s-%s-t%08d.%s", outputPath, name, simulationName, simulationId, time, ext);
}

/**
   Attempt to remove a file, if it exists.

   Params:
     fileName = file to remove
*/
void removeFile(const string fileName) {
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
void dumpData(T)(ref T L, uint t) {
  if ( t < startOutput ) {
    return;
  }

  // Checkpointing has its own routine.
  if (dumpNow(cpFreq,t)) {
    dumpCheckpoint(L, t);
    removeCheckpoint(L, t - (cpFreq * cpKeep)); 
  }

  if (dumpNow(fluidsFreq,t)) {
    foreach(i, ref e; L.fluids) {
      e.densityField(L.mask, L.density);
      L.density.dumpField("density-"~fieldNames[i], t);
    }
  }

  if (dumpNow(colourFreq,t)) {
    foreach(i, ref e; L.fluids) {
      for (size_t j = i + 1; j < L.fluids.length ; j++ ) {
	auto colour = colourField(L.fluids[i], L.fluids[j], L.mask);
	colour.dumpField("colour-"~fieldNames[i]~"-"~fieldNames[j],t);
      }
    }
  }

  if (dumpNow(velocitiesFreq,t)) {
    foreach(i, ref e; L.fluids) {
      auto velocity = e.velocityField!gconn(L.mask);
      velocity.dumpField("velocity-"~fieldNames[i], t);
    }
  }

  if (dumpNow(profileFreq,t)) {
    dumpProfiles(L,"profile",t);
  }

  if (dumpNow(forceFreq,t)) {
    foreach(i, ref e; L.force) {
      e.dumpField("force-"~fieldNames[i], t);
    }
  }

  if (dumpNow(maskFreq,t)) {
    L.mask.dumpField("mask", t);
  }
}

/**
   Data should be dumped if the frequency is larger than zero, and if the
   current timestep is a multiple of the frequency.

   Params:
     freq = dumping frequency
     t = current timestep
*/
private bool dumpNow(uint freq, uint t) {
  return ( freq > 0 && ( t % freq == 0 ));
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

/**
   Wrapper function to read a field from disk.
   Depending on the value of $(D outputFormat) the matching
   reading function will be called.

   Params:
     field = field to be read
     fileName = name of the file
*/
void readField(T)(ref T field, const string fileName) {
  Timers.io.start();
  final switch(outputFormat) {
  case FileFormat.Ascii:
    assert(0, "Ascii reading of fields not yet implemented.");
  case FileFormat.HDF5:
    readFieldHDF5(field, fileName);
    break;
  }
  Timers.io.stop();
}

