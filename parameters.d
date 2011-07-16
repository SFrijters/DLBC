import std.conv;
import std.file;
import std.stream;
import std.string;

import stdio;
import parallel;
import mpi;

alias parameterDataTypes PDT;
enum parameterDataTypes : string {
  Ulong  = "ulong",
  Bool   = "bool",
  Double = "double",
  Int    = "int",
  String = MpiStringType
};

/// This enum will be translated into various components through mixins
enum parameterTypes : string { 
  nx = PDT.Ulong, 
  ny = PDT.Ulong,
  nz = PDT.Ulong, 
  ncx = PDT.Int,
  ncy = PDT.Int,
  ncz = PDT.Int,
  ok =  PDT.Bool, 
  name = PDT.String,
  G = PDT.Double
};

/// This struct will be constructed from the parameterTypes enum
struct ParameterSet {
  mixin(makeParameterSetMembers());

  void show() {
    mixin(makeParameterSetShow());
  }
};

ParameterSet P;

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
  string mixinString = "string w;\n";
  foreach( member ; __traits(allMembers, parameterTypes)) {
    // Add a warning '!' for variables which are still equal to their default init.
    mixinString ~= "if ( P." ~ member ~ " == typeof(P." ~ member ~ ").init || P." ~ member ~ " != P." ~ member ~ ") w = \"!\"; else w = \"\";\n";
    // Actual print statement
    mixinString ~= "writelog(\"%1s %20s = %s\",w,\"" ~ member ~ "\",to!string(P." ~ member ~"));\n";
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
    mixinString ~= "catch (ConvException e) { writelog(\"  ConvException at line %d of the input file.\",ln); throw e; } \n";
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
  postfixString  = "MPI_Type_struct( " ~ to!string(count) ~ ", lens.ptr, disps.ptr, types.ptr, &parameterListMpiType );\n";
  postfixString ~= "MPI_Type_commit(&parameterListMpiType);\n";

  mixinString = prefixString ~ mainString ~ dispString ~ postfixString;
  return mixinString;
}

/// Creates an MPI datatype for the parameter struct using a mixin
void setupParameterSetMpiType() {
  mixin(makeParameterSetMpiType());
}

/// Sends and receives the parameter struct over MPI
void distributeParameterList() {
  MPI_Status status;
  if (M.rank == 0) {
    for (int dest = 1; dest < M.size; dest++ ) {
      MPI_Send(&P, 1, parameterListMpiType, dest, 0, M.comm);
    }
  }
  else {
    MPI_Recv(&P, 1, parameterListMpiType, 0, 0, M.comm, &status);
  }
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
      writelog("  Unknown key at line %d: <%s>", ln, keyString);
    }
  }

}

/// Parses a parameter file
void readParameterSetFromFile(string fileName) {
  File f = new File(fileName,FileMode.In);
  uint ln = 0;
  while(!f.eof()) {
    parseParameter(f.readLine(),++ln);
  }
  f.close();
}

