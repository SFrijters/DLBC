import std.conv;
import std.file;
import std.stream;
import std.string;

import lattice;
import logging;
import parallel;

string[] parameterFileNames;

/// This enum will be translated into various components through mixins
enum parameterTypes : string { 
  vl = PDT.Int,
  nx = PDT.Ulong, 
  ny = PDT.Ulong,
  nz = PDT.Ulong, 
  ncx = PDT.Int,
  ncy = PDT.Int,
  ncz = PDT.Int,
  haloSize = PDT.Int,
  ok = PDT.Bool, 
  name = PDT.String,
  G = PDT.Double
};

/// Enum containing strings of datatypes
alias parameterDataTypes PDT;
enum parameterDataTypes : string {
  Ulong  = "ulong",
  Bool   = "bool",
  Double = "double",
  Int    = "int",
  String = MpiStringType
};

/// This struct will be constructed from the parameterTypes enum
struct ParameterSetDefault {
  mixin(makeParameterSetDefaultMembers());
}


/// This struct will be constructed from the parameterTypes enum
struct ParameterSet {
  mixin(makeParameterSetMembers());

  void show() {
    writeLogI("\n*** Current parameter set:");
    mixin(makeParameterSetShow());
    writeLogI("***\n");
  }
};

ParameterSet P;
ParameterSetDefault PD;

/// Generates Mixin to create the ParameterSetDefault struct
string makeParameterSetDefaultMembers() {
  string mixinString, type;
  foreach( member ; __traits(allMembers, parameterTypes)) {
    mixinString ~= "bool " ~ member ~ " = true;\n";
  }
  return mixinString;
}

/// Generates Mixin to create the ParameterSet struct
string makeParameterSetMembers() {
  string mixinString, type;
  foreach( member ; __traits(allMembers, parameterTypes)) {
    type = mixin("parameterTypes." ~ member);
    // If we have a string, we have to set it to blank so we don't send trash through MPI
    if (type == MpiStringType) {
      mixinString ~= type ~ " " ~ member ~ " = \"\";\n";
    }
    else {
      mixinString ~= type ~ " " ~ member ~ ";\n";
    }
  }
  return mixinString;
}

/// Generates Mixin to list the values of P
string makeParameterSetShow() {
  string mixinString;
  foreach( member ; __traits(allMembers, parameterTypes)) {
    // Add a warning '!' for variables which are still equal to their default init.
    mixinString ~= "if ( PD." ~ member ~ ") { \n";
    // Actual print statement
    mixinString ~= "writeLogW(\"NOT SET %20s = %s\",\"" ~ member ~ "\",to!string(P." ~ member ~"));\n";
    mixinString ~= "}\nelse {\n";
    mixinString ~= "writeLogI(\"        %20s = %s\",\"" ~ member ~ "\",to!string(P." ~ member ~"));\n";
    mixinString ~= "}\n";
  }
  return mixinString;
}

/// Generates Mixin to create the cases for the parser
string makeParameterCase() {
  string mixinString;
  foreach( member ; __traits(allMembers, parameterTypes)) {
    string type = mixin("parameterTypes." ~ member);
    mixinString ~= "case \"" ~ member ~ "\": \n";
    mixinString ~= "try { ";
    if (type == MpiStringType) {
      mixinString ~= "P." ~ member ~ "[0 .. valueString.length] = valueString;";      
    }
    else {
      mixinString ~= "P." ~ member ~ " = to!" ~ type ~ "(valueString);";
    }
    mixinString ~= " } \n";
    mixinString ~= "catch (ConvException e) { writeLogE(\"  ConvException at line %d of the input file.\",ln); throw e; } \n";
    mixinString ~= "PD." ~ member ~ " = false;";
    mixinString ~= "break;\n";
  }
  return mixinString;
}

/// Generates Mixin to generate MPI Type for P
string makeParameterSetMpiType() {
  string mixinString, mainString, prefixString, postfixString, dispString;
  string type, mpiTypeString, lenString;
  int count;

  foreach( s ; __traits(allMembers, parameterTypes)) {
    type = mixin("parameterTypes." ~ s);
    final switch(type) {
    case PDT.Bool:   mpiTypeString = "MPI_BYTE";          lenString = "1"; break;
    case PDT.String: mpiTypeString = "MPI_CHAR";          lenString = to!string(MpiStringLength); break;
    case PDT.Double: mpiTypeString = "MPI_DOUBLE";        lenString = "1"; break;
    case PDT.Int:    mpiTypeString = "MPI_INT";           lenString = "1"; break;
    case PDT.Ulong:  mpiTypeString = "MPI_UNSIGNED_LONG"; lenString = "1"; break;
    }
    mainString ~= "lens[" ~ to!string(count) ~ "] = " ~ lenString ~ ";\n";
    mainString ~= "types[" ~ to!string(count) ~ "] = " ~ mpiTypeString ~ ";\n";
    mainString ~= "MPI_Address(&P." ~ s ~ ",&addrs[" ~ to!string(count+1) ~ "]);\n";
    count++;
  }

  for (uint i = 1; i <= count; i++) {
    dispString ~= "disps[" ~ to!string(i-1) ~ "] = addrs[" ~ to!string(i) ~ "] - addrs[0];\n";
  }

  prefixString   = "int[" ~ to!string(count) ~ "] lens;\n";
  prefixString  ~= "MPI_Aint[" ~ to!string(count) ~ "] disps;\n";
  prefixString  ~= "MPI_Aint[" ~ to!string(count+1) ~ "] addrs;\n";
  prefixString  ~= "MPI_Datatype[" ~ to!string(count) ~ "] types;\n";
  prefixString  ~= "MPI_Address(&P,&addrs[0]);\n";
  postfixString  = "MPI_Type_struct( " ~ to!string(count) ~ ", lens.ptr, disps.ptr, types.ptr, &parameterSetMpiType );\n";
  postfixString ~= "MPI_Type_commit(&parameterSetMpiType);\n";

  mixinString = prefixString ~ mainString ~ dispString ~ postfixString;
  return mixinString;
}

/// Creates an MPI datatype for the parameter struct using a mixin
void setupParameterSetMpiType() {
  writeLogRI("Setting up MPI type for parameter struct.");
  mixin(makeParameterSetMpiType());
}

/// Sends and receives the parameter struct over MPI
void distributeParameterSet() {
  immutable int mpiCount = 1;
  writeLogRI("Distributing parameter set through MPI_Bcast.");
  MPI_Bcast(&P, mpiCount, parameterSetMpiType, M.root, M.comm);
}

/// Parses a single line of the parameter file
void parseParameter(char[] line, in uint ln) {
  char[] keyString, valueString;

  auto commentPos = indexOf(line, "//");
  if (commentPos >= 0) {
    line = line[0 .. commentPos];
  }
 
  auto assignmentPos = indexOf(line, "=");
  if (assignmentPos > 0) {
    keyString = strip(line[0 .. assignmentPos]);
    valueString = strip(line[(assignmentPos+1) .. $]);
    switch(keyString) {
      // This mixin creates cases for all members of the parameterTypes struct
      mixin(makeParameterCase()); 
    default:
      writeLogRW("  Unknown key at line %d: <%s>", ln, keyString);
    }
  }

}

void readParameterSetFromFile(string fileName) {
  writeLogRI("Reading parameters from file '%s'.",fileName);

  File f;

  try {
    f = new File(fileName,FileMode.In);
  }
  catch (Exception e) {
    writeLogRF("Error opening parameter file '%s' for reading.",fileName);
    throw e;
  }
    
  uint ln = 0;
  while(!f.eof()) {
    parseParameter(f.readLine(),++ln);
  }
  f.close();
}

/// Parses a parameter file
void readParameterSetFromCliFiles() {
  if (parameterFileNames.length == 0) {
    writeLogRF("Parameter filename not set, please specify using the -p <filename> option.");
    throw new Exception("Parameter filename not set exception.");
  }

  foreach( fileName; parameterFileNames) {
    readParameterSetFromFile(fileName);
  }
}

/// Processes parameters
void processParameters() {
  // Set global verbosity level
  if ( !PD.vl ) {
    setGlobalVerbosityLevel( cast(VL) P.vl);
  }
}

/// Process CLI
void processCLI(string[] args) {

  writeLogRN("Processing command line arguments.");

  if (args.length > 1) {
    for (int i = 1; i < args.length; i++) {
      switch(args[i]) {
        case "-p": 
	  if (args.length > i+1) {
	    parameterFileNames = split(args[++i],",");
	    writeLogRI("Setting parameterFileNames to %s.",parameterFileNames);
	  }
	  else {
	    writeLogRW("Missing filename for -p <filename>.");
	  }
	  break;
        case "-v":
	  if (args.length > i+1) {
	    setGlobalVerbosityLevel( cast(VL) to!int(args[++i]) );
	  }
	  else {
	    writeLogRW("Missing verbosity for -v <verbositylevel>.");
	  }
	  break;
	default: writeLogRW("Unknown command line option '%s'.",args[i]);
      }
    }
  }
}

debug(showMixins) {

  import std.stdio: writeln;

  void dbgShowMixins() {

    setGlobalVerbosityLevel(VL.Debug);
    writeLogRD("--- START makeParameterSetMembers() mixin ---\n");
    writeln(makeParameterSetMembers());
    writeLogRD("--- END makeParameterSetMembers() mixin ---\n");

    writeLogRD("--- START makeParameterSetDefaultMembers() mixin ---\n");
    writeln(makeParameterSetDefaultMembers());
    writeLogRD("--- END makeParameterSetDefaultMembers() mixin ---\n");

    writeLogRD("--- START makeParameterSetShow() mixin ---\n");
    writeln(makeParameterSetShow());
    writeLogRD("--- END makeParameterSetShow() mixin ---\n");

    writeLogRD("--- START makeParameterSetMpiType() mixin ---\n");
    writeln(makeParameterSetMpiType());
    writeLogRD("--- END makeParameterSetMpiType() mixin ---\n");

    writeLogRD("--- START makeParameterCase() mixin ---\n");
    writeln(makeParameterCase());
    writeLogRD("--- END makeParameterCase() mixin ---\n");
  }
}

