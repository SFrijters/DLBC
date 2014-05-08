module dlbc.parparse;

import dlbc.logging;

import std.traits;
import std.typecons;

import std.conv;
import std.file;
import std.stream;
import std.string;


// import std.stdio;

import dlbc.parameters;

bool[string] paramIsSet;

auto createParameterMixins() {
  //  string[] parameterList;

  string mixinStringParser;
  string mixinStringShow;
  string mixinStringBcast;

  mixinStringParser ~= "void parse(const string keyString, const string valueString, const size_t ln) {\n";
  mixinStringParser ~= "switch(keyString) {\n\n";

  mixinStringShow ~= "void show(VL vl, LRF logRankFormat)() {\n";
  mixinStringShow ~= "  writeLog!(vl, logRankFormat)(\"Current parameter set:\");";

  //mixinStringShow ~= "vl = VL.Notification; logRankFormat = LRF.Root;";

  foreach(e ; __traits(derivedMembers, dlbc.parameters)) {
    mixin(`
      foreach( t; __traits(getAttributes, dlbc.parameters.`~e~`)) {
        if ( t == "param" ) {
          auto fullName = "dlbc.parameters." ~ e;

          mixinStringParser ~= "case \"`~e~`\":\n";
          static if ( isMutable!(typeof(`~e~`)) ) {
            mixinStringParser ~= "  try {\n";
            mixinStringParser ~= "    " ~ fullName ~ " = to!(typeof(" ~ fullName ~ "))( valueString );\n";
            mixinStringParser ~= "  }\n";
            mixinStringParser ~= "  catch (ConvException e) { writeLogE(\"  ConvException at line %d of the input file.\",ln); throw e; }\n";
            mixinStringParser ~= "  paramIsSet[\""~fullName~"\"] = true;\n  break;\n";
          }
          else {
            mixinStringParser ~= "  writeLogRW(\"Parameter '`~e~`' is not mutable.\");\n";
          }
          mixinStringParser ~= "\n";

          static if ( isMutable!(typeof(`~e~`)) ) {
            mixinStringShow ~= "  if ( ! (\""~fullName~"\" in paramIsSet ) ) { \n";
            mixinStringShow ~= "    writeLog!(VL.Warning, logRankFormat)(\"NOT SET %20s = %s\",\"`~e~`\",to!string(`~e~`));\n";
            mixinStringShow ~= "  }\n  else {\n";
            mixinStringShow ~= "    writeLog!(vl, logRankFormat)(\"        %20s = %s\",\"`~e~`\",to!string(`~e~`));\n";
            mixinStringShow ~= "  }\n";
          }
          else {
            mixinStringShow ~= "  writeLog!(vl, logRankFormat)(\"FIXED   %20s = %s\",\"`~e~`\",to!string(`~e~`));\n";
          }
          mixinStringShow ~= "\n";

          break;
        }
  }`);

  }
  mixinStringParser ~= "default:\n  writeLogRW(\"Unknown key at line %d: '%s'.\", ln, keyString);\n}\n\n";
  mixinStringParser ~= "}\n";

  mixinStringShow ~= "}\n";

  return mixinStringParser ~ "\n" ~ mixinStringShow;

}

// /// Generates Mixin to list the values of P
// auto createParameterSetShow() {
//   string mixinString;
//   foreach( member ; __traits(allMembers, parameterTypes)) {
//     string type = mixin("parameterTypes." ~ member);
//     // Add a warning 'NOT SET' for variables which are still equal to their default init.
//     mixinString ~= "if ( !paramIsSet[" ~ member ~ "]) { \n";
//     // Actual print statement
//     mixinString ~= "writeLog!(VL.Warning, logRankFormat)(\"NOT SET %20s = %s\",\"" ~ member ~ "\",to!string(P." ~ member ~ "));\n";
//     mixinString ~= "}\nelse {\n";
//     mixinString ~= "writeLog!(vl, logRankFormat)(\"        %20s = %s\",\"" ~ member ~ "\",to!string(P." ~ member ~ "));\n";
//     mixinString ~= "}\n";
//   }
//   return mixinString;
// }


mixin(createParameterMixins());

/// Parses a single line of the parameter file
void parseParameter(char[] line, const size_t ln) {
  char[] keyString, valueString;

  enum vl = VL.Notification;
  enum logRankFormat = LRF.Root;

  auto commentPos = indexOf(line, "//");
  if (commentPos >= 0) {
    line = line[0 .. commentPos];
  }
 
  auto assignmentPos = indexOf(line, "=");
  if (assignmentPos > 0) {
    keyString = strip(line[0 .. assignmentPos]);
    valueString = strip(line[(assignmentPos+1) .. $]);
    // This mixin creates cases for all members of the parameterTypes struct
    //mixin(makeParameterCase());
    parse(to!string(keyString), to!string(valueString), ln);
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

  show!(VL.Information, LRF.Root);
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

