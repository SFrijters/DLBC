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
   From which timestep to start writing files.
*/
@("param") int startOutput;

// Automatically add parameters for dumping frequencies of fields of the lattice.
// mixin(makeDumpFreqMixinString());

// Manually add dumping frequencies for derived quantities.
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
   Frequency at which force fields should be written to disk.
*/
@("param") int forceFreq;

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

  // Automatically allow lattice quantities to be dumped
  // mixin(makeDumpDataMixinString());

  // // Derived quantities
  // if (dumpNow(velFreq,t)) {
  //   auto v = L.red.velocityField!gconn(L.mask);
  //   v.dumpField("vel",t);
  // }

  if (dumpNow(profileFreq,t)) {
    dumpProfiles(L,"profile",t);
  }

  if (dumpNow(fluidsFreq,t)) {
    foreach(i, ref e; L.fluids) {
      e.densityField(L.mask, L.density);
      L.density.dumpField("density-"~fieldNames[i], t);
    }
  }

  if (dumpNow(forceFreq,t)) {
    foreach(i, ref e; L.force) {
      e.dumpField("force-"~fieldNames[i], t);
    }
  }

  if (dumpNow(fluidsFreq,t)) {
    foreach(i, ref e; L.fluids) {
      for (size_t j = i + 1; j < L.fluids.length ; j++ ) {
	auto colour = colourField(L.fluids[i], L.fluids[j], L.mask);
	colour.dumpField("colour-"~fieldNames[i]~"-"~fieldNames[j],t);
      }
    }
  }

}

/**
   Data should be dumped if the frequency is larger than zero, and if the
   current timestep is a multiple of the frequency.

   Params:
     freq = dumping frequency
     t = current timestep
*/
bool dumpNow(uint freq, uint t) {
  return ( freq > 0 && ( t % freq == 0 ));
}

/**
   Prepare a mixin that creates a frequency variable for all fields of the
   lattice struct marked with the @("field") UDA.
*/
private string makeDumpFreqMixinString() {
  string mixinString;

  foreach(e ; __traits(derivedMembers, dlbc.lattice.Lattice!(gconn))) {
    mixin(`
      static if ( __traits(compiles, __traits(getAttributes, dlbc.lattice.Lattice!(gconn).`~e~`))) {
        foreach( t; __traits(getAttributes, dlbc.lattice.Lattice!(gconn).`~e~`)) {
          if ( t == "field" ) {
            mixinString ~= "/**\n   Frequency at which the `~e~` field should be written to disk.\n*/";
	    mixinString ~= "@(\"param\") int "~e~"Freq;\n";
          }
        }
      }
     `);
  }
  return mixinString;
}

/**
   Prepare a mixin that creates a call to dumpField for all fields of the
   lattice struct marked with the @("field") UDA.
*/
private string makeDumpDataMixinString() {
  string mixinString;

  foreach(e ; __traits(derivedMembers, dlbc.lattice.Lattice!(gconn))) {
    mixin(`
      static if ( __traits(compiles, __traits(getAttributes, dlbc.lattice.Lattice!(gconn).`~e~`))) {
        foreach( t; __traits(getAttributes, dlbc.lattice.Lattice!(gconn).`~e~`)) {
          if ( t == "field" ) {
	    mixinString ~= "if ( dumpNow(`~e~`Freq, t)) {\n";
	    mixinString ~= "  L.`~e~`.dumpField(\"`~e~`\",t);\n";
            mixinString ~= "}\n";
          }
        }
      }
     `);
  }
  return mixinString;
}

