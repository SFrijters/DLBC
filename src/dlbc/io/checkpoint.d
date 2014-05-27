// Written in the D programming language.

/**
   Functions that handle (parallel) checkpoint I/O.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.io.checkpoint;

import dlbc.io.hdf5;
import dlbc.io.io;
import dlbc.lb.lb: fieldNames;
import dlbc.logging;

/**
   Path to create checkpoint files at, relative to $(D dlbc.io.outputPath).
*/
@("param") string cpPath = ".";
/**
   Frequency at which checkpoints should be written to disk.
*/
@("param") int cpFreq;

/**
   Write a checkpoint to disk. A full checkpoint currently includes:
   - The full populations of all fluid components.
   - The mask.

   Params:
     L = the lattice
     t = current time step
*/
void dumpCheckpoint(T)(ref T L, uint t) {
  foreach(i, ref e; L.fluids) {
    e.dumpFieldHDF5("cp-"~fieldNames[i], t, true);
  }
  L.mask.dumpFieldHDF5("cp-mask", t, true);
}

/**
   Read a checkpoint from disk. A full checkpoint currently includes:
   - The full populations of all fluid components. The checkpoint to be restored depends
     on the value of $(D restoreString).
   - The mask.

   Params:
     L = the lattice
*/
void readCheckpoint(T)(ref T L) {
  string fileName;
  writeLogRI("The simulation will be restored from checkpoint `%s'.", restoreString);
  foreach(i, ref e; L.fluids) {
    fileName = makeFilenameCpRestore!(FileFormat.HDF5)("cp-"~fieldNames[i], restoreString);
    e.readFieldHDF5(fileName, true);
  }
  fileName = makeFilenameCpRestore!(FileFormat.HDF5)("cp-mask", restoreString);
  L.mask.readFieldHDF5(fileName, true);
  writeLogRI("The simulation has been restored and will continue at the next timestep.");
}

/**
   First broadcasts the value of the restore string to all processes,
   and then decides if we are restoring something or not.
*/
bool isRestoring() {
  broadcastRestoreString();
  if ( restoreString ) {
    return true;
  }
  else {
    return false;
  }
}

/**
   Ensure that the restoreString is globally the same, by broadcasting the value
   from the root process. This function should be called early in the simulation,
   but definitely before any IO has been performed.
*/
private void broadcastRestoreString() {
  import dlbc.parallel: MpiBcastString;
  MpiBcastString(restoreString);
}

/**
   Creates a filename based on the file format (which determines the extension),
   the global parameters $(D outputPath), $(D cpPath) and $(D simulationName) and the automatically
   generated $(D simulationId). A custom name can be supplied, which will be prepended.

   Params:
     name = name of the field, to be prepended to the file name
*/
string makeFilenameCpOutput(FileFormat fileFormat)(const string name, const uint time) {
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
  return format("%s/%s/%s-%s-t%08d-%s.%s", outputPath, cpPath, name, simulationName, time, simulationId, ext);
}

/**
   Creates a filename based on the file format (which determines the extension),
   the global parameters $(D outputPath), $(D cpPath) and $(D simulationName) and the automatically
   generated $(D simulationId). A custom name can be supplied, which will be prepended.

   Params:
     name = name of the field, to be prepended to the file name
*/
string makeFilenameCpRestore(FileFormat fileFormat)(const string name, const string simulationName) {
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
  return format("%s/%s/%s-%s.%s", outputPath, cpPath, name, simulationName, ext);
}

