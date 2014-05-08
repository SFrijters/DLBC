module dlbc.parparse;

import dlbc.logging;

import std.traits;
import std.typecons;

import std.conv;
import std.file;
import std.stream;
import std.string;

import dlbc.parallel;

// import std.stdio;

import dlbc.parameters;

private string[] setParams;

immutable string parameterUDA = "param";

auto createParameterMixins() {
  string mixinStringParser;
  string mixinStringShow;
  string mixinStringBcast;

  mixinStringParser ~= "void parse(const string keyString, const string valueString, const size_t ln) {\n";
  mixinStringParser ~= "switch(keyString) {\n\n";

  mixinStringShow ~= "void show(VL vl, LRF logRankFormat)() {\n  import std.algorithm;\n";
  mixinStringShow ~= "  writeLog!(vl, logRankFormat)(\"Current parameter set:\");";

  mixinStringBcast ~= "void broadcastParameters() {\n";

  immutable string fullModuleName = "dlbc.parameters";
  immutable string qualModuleName = "parameters";

  foreach(e ; __traits(derivedMembers, dlbc.parameters)) {
    mixin(`
      foreach( t; __traits(getAttributes, `~fullModuleName~`.`~e~`)) {
        if ( t == "`~parameterUDA~`" ) {
          auto fullName = "`~fullModuleName~`." ~ e;
          auto qualName = "`~qualModuleName~`." ~ e;

          mixinStringParser ~= "case \""~qualName~"\":\n";
          static if ( isMutable!(typeof(`~fullModuleName~`.`~e~`)) ) {
            mixinStringParser ~= "  try {\n";
            mixinStringParser ~= "    " ~ fullName ~ " = to!(typeof(" ~ fullName ~ "))( valueString );\n";
            mixinStringParser ~= "  }\n";
            mixinStringParser ~= "  catch (ConvException e) { writeLogE(\"  ConvException at line %d of the input file.\",ln); throw e; }\n";
            mixinStringParser ~= "  setParams ~= \""~fullName~"\"; break;\n";
          }
          else {
            mixinStringParser ~= "  writeLogRW(\"Parameter '"~qualName~"' is not mutable.\");\n";
          }
          mixinStringParser ~= "\n";

          static if ( isMutable!(typeof(`~fullModuleName~`.`~e~`)) ) {
            mixinStringShow ~= "  if ( ! ( setParams.canFind(\""~fullName~"\") ) ) { \n";
            mixinStringShow ~= "    writeLog!(VL.Warning, logRankFormat)(\"NOT SET %20s = %s\",\"`~e~`\",to!string("~fullName~"));\n";
            mixinStringShow ~= "  }\n  else {\n";
            mixinStringShow ~= "    writeLog!(vl, logRankFormat)(\"        %20s = %s\",\"`~e~`\",to!string("~fullName~"));\n";
            mixinStringShow ~= "  }\n";
          }
          else {
            mixinStringShow ~= "  writeLog!(vl, logRankFormat)(\"FIXED   %20s = %s\",\"`~e~`\",to!string("~fullName~"));\n";
          }
          mixinStringShow ~= "\n";

          static if ( isMutable!(typeof(`~fullModuleName~`.`~e~`)) ) {
            static if ( is( typeof(`~fullModuleName~`.`~e~`) == string) ) {
              mixinStringBcast ~= "  MpiBcastString("~fullName~");\n";
            }
            else {
              mixinStringBcast ~= "  MPI_Bcast(&" ~ fullName ~ ", 1, mpiTypeof!(typeof(" ~ fullName ~")), M.root, M.comm);\n";
            }
          }

          break;
        }
  }`);

  }
  mixinStringParser ~= "default:\n  writeLogRW(\"Unknown key at line %d: '%s'.\", ln, keyString);\n}\n\n";
  mixinStringParser ~= "}\n";

  mixinStringShow ~= "}\n";

  mixinStringBcast ~= "}\n";

  return mixinStringParser ~ "\n" ~ mixinStringShow ~ "\n" ~ mixinStringBcast;

}

mixin(createParameterMixins());

/// Parses a single line of the parameter file
void parseParameter(char[] line, const size_t ln, ref string currentSection) {
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
    if ( currentSection != "" ) {
      parse(currentSection~"."~to!string(keyString), to!string(valueString), ln);
    }
    else {
      parse(to!string(keyString), to!string(valueString), ln);
    }
  }
  else {
    import std.regex;
    auto r = regex(r"\[(.*?)\]", "g");
    foreach(c; match(line, r)) {
      currentSection = to!string(c.captures[1]);
      writeLogRD("Entering section %s.", currentSection);
    }
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
  string currentSection;
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
    parseParameter(f.readLine(),++ln,currentSection);
  }
  f.close();
}

