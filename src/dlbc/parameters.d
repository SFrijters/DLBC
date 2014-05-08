// Written in the D programming language.
module dlbc.parameters;

import std.conv;
import std.file;
import std.stream;
import std.string;

import dlbc.logging;
import dlbc.parallel;

string[] parameterFileNames;


const int test = 1;
@("param") immutable int test2 = 2;
@("param") int test3 = 3;
@("param") const string stest = "1";
immutable string stest2 = "2";
@("param") string stest3 = "3";
@("param") string stest4 = "4";

/** This enum will be translated into various components through mixins.
    It contains pairs of variable names and their type value, as defined
    through the $(D parameterDataTypes) enum.
*/
enum parameterTypes : string {
  nx = PDT.Ulong,
  ny = PDT.Ulong,
  nz = PDT.Ulong,
  ncx = PDT.Int,
  ncy = PDT.Int,
  ncz = PDT.Int,
  seed = PDT.Int,
  haloSize = PDT.Int,
  ok = PDT.Bool,
  name = PDT.String,
  G = PDT.Double
};

/// Enum containing strings of datatypes
alias parameterDataTypes PDT;
/// Ditto
enum parameterDataTypes : string {
  Ulong  = "ulong",
  Bool   = "bool",
  Double = "double",
  Int    = "int",
  String = MpiStringType()
};

/// This struct will be constructed from the parameterTypes enum
struct ParameterSet {
  mixin(makeParameterSetMembers());

  void show(VL vl, LRF logRankFormat)() {
    writeLog!(vl, logRankFormat)("Current parameter set:");
    mixin(makeParameterSetShow());
  }
}

/// This struct will be constructed from the parameterTypes enum
struct ParameterSetDefault {
  mixin(makeParameterSetDefaultMembers());
}

ParameterSet P;
ParameterSetDefault PD;

/// Generates Mixin to create the ParameterSetDefault struct
string makeParameterSetDefaultMembers() pure nothrow @safe {
  string mixinString;
  foreach( member ; __traits(allMembers, parameterTypes)) {
    mixinString ~= "bool " ~ member ~ " = true;\n";
  }
  return mixinString;
}

/// Generates Mixin to create the ParameterSet struct
string makeParameterSetMembers() /* pure */  nothrow @safe { // GDC bug?
  string mixinString, type;
  foreach( member ; __traits(allMembers, parameterTypes)) {
    type = mixin("parameterTypes." ~ member);
    // If we have a string, we have to set it to blank so we don't send trash through MPI
    if (type == MpiStringType()) {
      mixinString ~= type ~ " " ~ member ~ " = \"\";\n";
    }
    else {
      mixinString ~= type ~ " " ~ member ~ ";\n";
    }
  }
  return mixinString;
}

/// Generates Mixin to list the values of P
string makeParameterSetShow() pure nothrow @safe {
  string mixinString;
  foreach( member ; __traits(allMembers, parameterTypes)) {
    string type = mixin("parameterTypes." ~ member);
    // Add a warning 'NOT SET' for variables which are still equal to their default init.
    mixinString ~= "if ( PD." ~ member ~ ") { \n";
    // Actual print statement
    mixinString ~= "writeLog!(VL.Warning, logRankFormat)(\"NOT SET %20s = %s\",\"" ~ member ~ "\",to!string(P." ~ member ~ "));\n";
    mixinString ~= "}\nelse {\n";
    mixinString ~= "writeLog!(vl, logRankFormat)(\"        %20s = %s\",\"" ~ member ~ "\",to!string(P." ~ member ~ "));\n";
    mixinString ~= "}\n";
  }
  return mixinString;
}

/// Generates Mixin to create the cases for the parser
string makeParameterCase() /* pure */ nothrow @safe { // GDC bug?
  string mixinString;
  // Fill all char[256] with spaces.
  foreach( member ; __traits(allMembers, parameterTypes)) {
    string type = mixin("parameterTypes." ~ member);
    if (type == MpiStringType()) {
      mixinString ~= "for(size_t i = 0; i < MpiStringLength; i++) { P." ~ member ~ "[i] = ' '; }";
    }
  }
  // Create the switch statement.
  mixinString ~= "switch(keyString) {\n";
  foreach( member ; __traits(allMembers, parameterTypes)) {
    string type = mixin("parameterTypes." ~ member);
    mixinString ~= "case \"" ~ member ~ "\":\n";
    mixinString ~= "try {";
    if (type == MpiStringType()) {
      mixinString ~= "P." ~ member ~ "[0 .. valueString.length] = valueString;";
    }
    else {
      mixinString ~= "P." ~ member ~ " = to!" ~ type ~ "(valueString);";
    }
    mixinString ~= " }\n";
    mixinString ~= "catch (ConvException e) { writeLogE(\"  ConvException at line %d of the input file.\",ln); throw e; }\n";
    mixinString ~= "PD." ~ member ~ " = false;";
    mixinString ~= "break;\n";
  }
  mixinString ~= "default:\nwriteLogRW(\"Unknown key at line %d: '%s'.\", ln, keyString); }";
  return mixinString;
}

/// Generates Mixin to generate MPI Type for P
string makeParameterSetMpiType() pure @safe {
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
  postfixString  = "MPI_Type_create_struct( " ~ to!string(count) ~ ", lens.ptr, disps.ptr, types.ptr, &parameterSetMpiType );\n";
  postfixString ~= "MPI_Type_commit(&parameterSetMpiType);\n";

  mixinString = prefixString ~ mainString ~ dispString ~ postfixString;
  return mixinString;
}

/// Creates an MPI datatype for the parameter struct using a mixin
void setupParameterSetMpiType() {
  writeLogRI("Setting up MPI type for parameter struct.");
  mixin(makeParameterSetMpiType());
}

/// Generates Mixin to generate MPI Type for PD
string makeParameterSetDefaultMpiType() pure @safe {
  string mixinString, mainString, prefixString, postfixString, dispString;
  string type, mpiTypeString, lenString;
  int count = 0;

  foreach( s ; __traits(allMembers, parameterTypes)) {
    mainString ~= "lens[" ~ to!string(count) ~ "] = 1;\n";
    mainString ~= "types[" ~ to!string(count) ~ "] = MPI_BYTE;\n";
    mainString ~= "MPI_Address(&PD." ~ s ~ ",&addrs[" ~ to!string(count+1) ~ "]);\n";
    count++;
  }

  for (uint i = 1; i <= count; i++) {
    dispString ~= "disps[" ~ to!string(i-1) ~ "] = addrs[" ~ to!string(i) ~ "] - addrs[0];\n";
  }

  prefixString   = "int[" ~ to!string(count) ~ "] lens;\n";
  prefixString  ~= "MPI_Aint[" ~ to!string(count) ~ "] disps;\n";
  prefixString  ~= "MPI_Aint[" ~ to!string(count+1) ~ "] addrs;\n";
  prefixString  ~= "MPI_Datatype[" ~ to!string(count) ~ "] types;\n";
  prefixString  ~= "MPI_Address(&PD,&addrs[0]);\n";
  postfixString  = "MPI_Type_create_struct( " ~ to!string(count) ~ ", lens.ptr, disps.ptr, types.ptr, &parameterSetDefaultMpiType );\n";
  postfixString ~= "MPI_Type_commit(&parameterSetDefaultMpiType);\n";

  mixinString = prefixString ~ mainString ~ dispString ~ postfixString;
  return mixinString;
}

/// Creates an MPI datatype for the parameter default struct using a mixin
void setupParameterSetDefaultMpiType() {
  writeLogRI("Setting up MPI type for parameter default struct.");
  mixin(makeParameterSetDefaultMpiType());
}

/// Sends and receives the parameter struct over MPI
void distributeParameterSet() {
  immutable int mpiCount = 1;
  writeLogRI("Distributing parameter set through MPI_Bcast.");
  MPI_Bcast(&P, mpiCount, parameterSetMpiType, M.root, M.comm);
  writeLogRI("Distributing parameter set default through MPI_Bcast.");
  MPI_Bcast(&PD, mpiCount, parameterSetDefaultMpiType, M.root, M.comm);
}

/// Parses a single line of the parameter file
void parseParameter(char[] line, const size_t ln) {
  char[] keyString, valueString;

  auto commentPos = indexOf(line, "//");
  if (commentPos >= 0) {
    line = line[0 .. commentPos];
  }
 
  auto assignmentPos = indexOf(line, "=");
  if (assignmentPos > 0) {
    keyString = strip(line[0 .. assignmentPos]);
    valueString = strip(line[(assignmentPos+1) .. $]);
    // This mixin creates cases for all members of the parameterTypes struct
    mixin(makeParameterCase());
  }
}

/// Parses a parameter file
void readParameterSetFromCliFiles() {
  if (parameterFileNames.length == 0) {
    writeLogRF("Parameter filename not set, please specify using the -p <filename> option.");
  }
  foreach( fileName; parameterFileNames) {
    readParameterSetFromFile(fileName);
  }
}

void readParameterSetFromFile(const string fileName) {
  File f;
  writeLogRI("Reading parameters from file '%s'.",fileName);

  try {
    f = new File(fileName,FileMode.In);
  }
  catch (OpenException e) {
    writeLogRF("Error opening parameter file '%s' for reading.", fileName);
  }

  size_t ln = 0;
  while(!f.eof()) {
    parseParameter(f.readLine(),++ln);
  }
  f.close();
}

/// Processes parameters
void processParameters() pure nothrow @safe {

}

debug(showMixins) {

  import std.stdio: writeln;

  void dbgShowMixins() {

    setGlobalVerbosityLevel(VL.Debug);
    writeLogRD("--- START makeParameterSetMembers() mixin ---\n");
    if (M.isRoot() ) writeln(makeParameterSetMembers());
    writeLogRD("--- END makeParameterSetMembers() mixin ---\n");

    writeLogRD("--- START makeParameterSetDefaultMembers() mixin ---\n");
    if (M.isRoot() ) writeln(makeParameterSetDefaultMembers());
    writeLogRD("--- END makeParameterSetDefaultMembers() mixin ---\n");

    writeLogRD("--- START makeParameterSetShow() mixin ---\n");
    if (M.isRoot() ) writeln(makeParameterSetShow());
    writeLogRD("--- END makeParameterSetShow() mixin ---\n");

    writeLogRD("--- START makeParameterSetMpiType() mixin ---\n");
    if (M.isRoot() ) writeln(makeParameterSetMpiType());
    writeLogRD("--- END makeParameterSetMpiType() mixin ---\n");

    writeLogRD("--- START makeParameterSetDefaultMpiType() mixin ---\n");
    if (M.isRoot() ) writeln(makeParameterSetDefaultMpiType());
    writeLogRD("--- END makeParameterSetDefaultMpiType() mixin ---\n");

    writeLogRD("--- START makeParameterCase() mixin ---\n");
    if (M.isRoot() ) writeln(makeParameterCase());
    writeLogRD("--- END makeParameterCase() mixin ---\n");
  }
}

