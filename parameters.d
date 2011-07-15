import std.conv;
import std.file;
import std.stream;
import std.string;

import stdio;

enum parameterTypes : string { nx = "ulong", ny = "ulong", nz = "ulong", ok = "bool", name = "string", G = "double"};

struct ParameterSet {
  mixin(makeStructMembers());
}

ParameterSet P;

/// Generates Mixin to create the ParameterSet struct
string makeStructMembers() {
  string members, member, type;
  foreach( s ; __traits(allMembers, parameterTypes)) {
    member = s;
    type = mixin("parameterTypes." ~ s);
    members ~= type ~ " " ~ member ~ "; ";
  }
  return members;
}

/// Generates Mixin to create the cases for the parser
string makeParameterCase() {
  string caseString;
  foreach( s ; __traits(allMembers, parameterTypes)) {
    string type = mixin("parameterTypes." ~ s);
    caseString ~= "
      case \"" ~ s ~ "\": 
        try {
        P." ~ s ~ " = to!" ~ type ~ "(valueString);
        }
        catch (ConvException e) {
          writelog(\"  ConvException at line %d of the input file.\",ln);
          throw e; 
        }
        break;
      ";
  }
  return caseString;
}

/// Generates Mixin to list the values of P
string makeParameterList() {
  string outputString;
  foreach( s ; __traits(allMembers, parameterTypes)) {
    // Add a warning '!' for variables which are still equal to their default init.
    outputString ~= "if ( P." ~ s ~ " == typeof(P." ~ s ~ ").init || P." ~ s ~ " != P." ~ s ~ ") w = \"!\"; else w = \"\";";
    // Actual print statement
    outputString ~= "writelog(\"%1s %20s = %s\",w,\"" ~ s ~ "\",to!string(P." ~ s ~")); ";
  }
  return outputString;
}


void listParameterValues() {
  string w; // Will contain warning signs
  mixin(makeParameterList());
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
