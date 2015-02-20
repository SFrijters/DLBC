// Written in the D programming language.

/**
   Functions that handle (parallel) checkpoint I/O.

   Variables that hold global state and need to be saved/restored
   are to be annotated with the @("global") UDA.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.io.checkpoint;

import dlbc.io.hdf5;
import dlbc.io.io;
import dlbc.lb.lb: fieldNames;
import dlbc.elec.elec: enableElec;
import dlbc.lattice;
import dlbc.logging;
import dlbc.parallel;
import dlbc.timers;
import std.typecons;
import dlbc.fields.field: isField;

mixin(createImports());

/**
   Path to create checkpoint files at, relative to $(D dlbc.io.outputPath).
*/
@("param") string cpPath = ".";
/**
   Frequency at which checkpoints should be written to disk.
*/
@("param") int cpFreq;
/**
   How many checkpoints to keep.
*/
@("param") int cpKeep = 1;

/**
   The UDA to be used to denote a global state holding variable.
*/
static immutable string globalUDA = "global";

/**
   A list of modules that have to be scanned for variables that hold global state.

   Bugs:
     Ideally this should be a template parameter to the createCheckpointMixins function, maybe?
*/
private alias globalsSourceModules = TypeTuple!(
                         "dlbc.lb.lb",
                         "dlbc.parameters",
                         );

private bool hasAttribute(alias attr, string field)() @safe pure nothrow {
  import std.typetuple;
  static if(__traits(compiles, __traits(getAttributes, mixin(field)))) {
    alias attrs = TypeTuple!(__traits(getAttributes, mixin(field)));
    return staticIndexOf!(attr, attrs) != -1;
  }
  else {
    return false;
  }
}  

private bool isCpField(string field)() @safe pure nothrow {
  return hasAttribute!(Exchange, field);
}

private auto createCheckpointMixins() {
  import std.traits;

  string mixinStringDump;
  string mixinStringRemove;
  string mixinStringRead;

  foreach(e ; __traits(derivedMembers, dlbc.lattice.Lattice!gconn)) {
    enum s = "Lattice!gconn."~e;
    static if (isCpField!(s)) {
      static if (isField!(typeof(mixin(s))) ) {
        mixinStringDump ~= "L." ~ e ~ ".dumpFieldHDF5(\"cp-"~e~"\", t, true);";
        mixinStringRead ~= "fileName = makeFilenameCpRestore!(FileFormat.HDF5)(\"cp-"~e~"\", restoreString);\n  L."~e~".readFieldHDF5(fileName, true);\n";
        mixinStringRemove ~= "makeFilenameCpOutput!(FileFormat.HDF5)(\"cp-"~e~"\", t).removeFile();";
      }
      else {
        mixinStringDump ~= "foreach(immutable i, ref e; L."~e~") { e.dumpFieldHDF5(\"cp-"~e~"\"~to!string(i), t, true); }";
        mixinStringRead ~= "foreach(immutable i, ref e; L."~e~") {\n  fileName = makeFilenameCpRestore!(FileFormat.HDF5)(\"cp-"~e~"\"~to!string(i), restoreString);\n  e.readFieldHDF5(fileName, true);\n}\n";
        mixinStringRemove ~= "foreach(immutable i, ref e; L."~e~") { makeFilenameCpOutput!(FileFormat.HDF5)(\"cp-"~e~"\"~to!string(i), t).removeFile(); }";
      }
    }
  }
  return [ mixinStringDump, mixinStringRead, mixinStringRemove ];
}

private immutable checkpointMixins = createCheckpointMixins();

/**
   Write a checkpoint to disk. A full checkpoint currently includes:
   - The full populations of all fluid components.
   - The mask.

   Params:
     L = the lattice
     t = current time step
*/
void dumpCheckpoint(T)(ref T L, uint t) {
  startTimer("main.io.cp");
  writeLogRN("Writing checkpoint for t = %d.", t);
  mixin(checkpointMixins[0]);
  stopTimer("main.io.cp");
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
  startTimer("main.io.cp");
  writeLogRI("The simulation will be restored from checkpoint `%s'.", restoreString);
  mixin(checkpointMixins[1]);
  writeLogRI("The simulation has been restored and will continue at the next timestep.");
  stopTimer("main.io.cp");
}

/**
   Delete a checkpoint from disk. A full checkpoint currently includes:
   - The full populations of all fluid components.
   - The mask.

   Params:
     L = the lattice
     t = time step to delete
*/
void removeCheckpoint(T)(ref T L, int t) {
  if ( t < 0 ) return;
  startTimer("main.io.cp");
  writeLogRN("Removing checkpoint for t = %d.", t);
  mixin(checkpointMixins[2]);
  stopTimer("main.io.cp");
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
     time = current timestep
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
  return format("%s/%s/%s-%s-%s-t%08d.%s", outputPath, cpPath, name, simulationName, simulationId, time, ext);
}

/**
   Creates a filename based on the file format (which determines the extension),
   the global parameters $(D outputPath), $(D cpPath) and $(D simulationName) and the automatically
   generated $(D simulationId). A custom name can be supplied, which will be prepended.

   Params:
     name = name of the field, to be prepended to the file name
     simulationName = used in the file name
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

mixin(createGlobalsMixins());

/**
   Creates an string mixin to define $(D dumpCheckpointGlobals), $(D readCheckpointGlobals), and $(D  broadcastCheckpointGlobals ).
*/
private auto createGlobalsMixins() {
  string mixinStringDump;
  string mixinStringRead;
  string mixinStringBcast;

  mixinStringDump ~= `
  /**
     Write the designated global variables as attributes.

     Params:
       fileName = file to write to, in C string format
  */
  void dumpCheckpointGlobals(const char* fileName) {
    auto file_id = H5Fopen(fileName, H5F_ACC_RDWR, H5P_DEFAULT);
    auto root_id = H5Gopen2(file_id, "/", H5P_DEFAULT);
    auto group_id = H5Gcreate2(root_id, "globals", H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
  `;
  mixinStringRead ~= `
  /**
     Read the designated global variables as attributes.

     Params:
       fileName = file to read from, in C string format
  */
  void readCheckpointGlobals(const char* fileName) {
    auto file_id = H5Fopen(fileName, H5F_ACC_RDONLY, H5P_DEFAULT);
    auto root_id = H5Gopen2(file_id, "/", H5P_DEFAULT);
    auto group_id = H5Gopen2(root_id, "globals", H5P_DEFAULT);
  `;

  mixinStringBcast ~= `
  /**
     Broadcast restored global variables.
  */
  void broadcastCheckpointGlobals() {
  `;

  foreach(fullModuleName ; globalsSourceModules) {
    foreach(e ; __traits(derivedMembers, mixin(fullModuleName))) {
      mixin(`
      static if ( __traits(compiles, __traits(getAttributes, `~fullModuleName~`.`~e~`))) {
        foreach( t; __traits(getAttributes, `~fullModuleName~`.`~e~`)) {
          if ( t == "`~globalUDA~`" ) {
            auto fullName = "`~fullModuleName~`." ~ e;

            mixinStringDump ~= "  writeLogRD(\"Saving "~fullName~" = %s.\","~fullName~");\n";
            mixinStringDump ~= "    dumpAttributeHDF5("~fullName~", \""~fullName~"\", group_id);\n";
            mixinStringRead ~= "  "~fullName~" = readAttributeHDF5!(typeof("~fullName~"))(\""~fullName~"\", group_id);\n";
            mixinStringRead ~= "    writeLogRD(\"Restored "~fullName~" = %s.\","~fullName~");\n";

            mixinStringBcast ~= "  MPI_Bcast(&"~fullName~", 1, mpiTypeof!(typeof("~fullName~")), M.root, M.comm);\n";

            break;
          }
        }
      }`);
    }
  }
  mixinStringDump ~= "    H5Gclose(group_id);\n    H5Gclose(root_id);\n    H5Fclose(file_id);\n  }\n";

  mixinStringRead ~= "    H5Gclose(group_id);\n    H5Gclose(root_id);\n    H5Fclose(file_id);\n  }\n";

  mixinStringBcast ~= "  }\n";

  return mixinStringDump ~ "\n" ~ mixinStringRead ~ "\n" ~ mixinStringBcast;
}

/**
   Creates an string mixin to import the modules specified in $(D globalsSourceModules).
*/
private auto createImports() {
  string mixinString;

  foreach(fullModuleName; globalsSourceModules) {
    mixinString ~= "import " ~ fullModuleName ~ ";";
  }
  return mixinString;
}

