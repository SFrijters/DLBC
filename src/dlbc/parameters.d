// Written in the D programming language.

/**
   Helper functions for reading, storage and communication of simulation parameters.

   Parameters in DLBC are stored in their relevant modules. This module exists
   to look for parameters in the modules named in the $(D parameterSourceModules)
   tuple. Parameters to be included are to be given the @("param") UDA. A parser
   is then constructed that parses a line of an input file and assigns its value
   to the correct variable. In addition a function is generated to broadcast all
   parameters via MPI to all processes, and another one to show the current values
   of all parameters.

   Input files have a simple structure. Parameters can be speficied by including the
   module name (leaving off '$(D dlbc.)') in front of the variable name, or by first
   creating a section corresponding to a module. This is achieved by enclosing the
   name of the module in square brackets. Single-line comments are supported and 
   denoted by '$(D //)'. Everything after this on a line is ignored. Similarly, empty
   lines are ignored. The syntax for setting a parameter value is simply $(D 'foo = bar'),
   where $(D foo) is the name of the parameter and everything to the right of the equal
   sign is treated as the value. This value is then converted into its proper data
   type via $(D to!(type)). A failure to convert the value is treated as an error.

   Example:
   ----
   // This is a comment
   // Multiline comments are not supported

   lattice.gnx = 32   // Fully qualified parameter name

   [parallel]         // This is a section header
   ncy = 2            // This now corresponds to parallel.ncy

   [lattice]
   gnx = 32           // Later versions of the same parameter cause a warning

   []                 // This is a bit dirty, but actually resets the section name
   lattice.gny = 16   // So now one needs to use fully qualified names again
   lattice.gnz = 8

   io.output = path/to/output    // String values are used without quotes

   foo.bar = 42       // Unknown parameter names cause a warning
   ----
   Parameters that have the prerequisite UDA set, but are also immutable, will be
   reported as warnings if an input file specifies a value for that parameter.

   When the parameters are shown using the $(D showParameters) function, they will be
   shown per module (in the order they have been specified in $(D parameterSourceModules) )
   and may be given a prefix: '$(D !)' denotes a parameter that has not been given a value
   in the input files (and as such is at its default value) and '$(D x)' denotes a parameter
   that has been marked as immutable.

   The meaning of the parameters is described at their respective locations in the
   code and documentation.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.parameters;

import std.conv;
import std.string;
import std.traits;
import std.typecons;

import dlbc.logging;
import dlbc.parallel;

mixin(createImports());

/**
   List of input file names.
*/
string[] parameterFileNames;

/**
   The UDA to be used to denote a parameter variable.
*/
static immutable string parameterUDA = "param";

/**
   A list of modules that have to be scanned for parameters.

   Bugs:
     Ideally this should be a template parameter to the createParameterMixins function, maybe?
*/
private alias TypeTuple!(
			 "dlbc.lattice",
			 "dlbc.logging",
			 "dlbc.parallel",
			 "dlbc.random",
			 ) parameterSourceModules;
/**
   List of parameters that have been set in the input files.
*/
private string[] setParams;

/**
   Loops over all specified parameter files $(D parameterFileNames) in order to parse them.
   If no files are specified, a fatal error is logged.
*/
void readParameterSetFromCliFiles() {
  if (parameterFileNames.length == 0) {
    writeLogRF("Parameter filename not set, please specify using the -p <filename> option.");
  }
  foreach( fileName; parameterFileNames) {
    readParameterSetFromFile(fileName);
  }
}

/**
   Does things that need to be done after the parameters are read.
   Currently a no-op.
*/
void processParameters() pure nothrow @safe {

}

/**
   Parses a single line of a parameter file.

   Params:
     line = line to parse
     ln = current line number
     currentSection = current section --- this can be updated if we encounter
                      a section header
*/
private void parseParameter(char[] line, const size_t ln, ref string currentSection) {
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
      parseParameter(currentSection~"."~to!string(keyString), to!string(valueString), ln);
    }
    else {
      parseParameter(to!string(keyString), to!string(valueString), ln);
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

/**
   Attempt to parse a single input file.

   Params:
     fileName = name of the file to be parsed
*/
private void readParameterSetFromFile(const string fileName) {
  import std.file;
  import std.stream;

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

mixin(createParameterMixins());

/**
   Creates an string mixin to define $(D parseParameter), $(D showParameters), and $(D bcastParameters).
*/
private auto createParameterMixins() {
  string mixinStringParser;
  string mixinStringShow;
  string mixinStringBcast;

  mixinStringParser ~= `
  /**
     Attempt to parse a single parameter, by converting it to the correct datatype and assigning the result to its matching variable.

     Params:
       keyString = qualified name of the parameter
       valueString = value to be assigned
       ln = line number (for more useful warnings)
  */
  `;
  mixinStringParser ~= "private void parseParameter(const string keyString, const string valueString, const size_t ln) {\n  import std.algorithm;\n";
  mixinStringParser ~= "switch(keyString) {\n\n";

  mixinStringShow ~= `
  /**
     Show the current parameter set.

     Params:
       vl = verbosity level to write at
       logRankFormat = which processes should write
  */
  `;
  mixinStringShow ~= "void showParameters(VL vl, LRF logRankFormat)() {\n  import std.algorithm;\n";
  mixinStringShow ~= "  writeLog!(vl, logRankFormat)(\"Current parameter set:\");";

  mixinStringBcast ~= `
  /**
     Broadcast all parameters from the root process to all other processes.
  */
  `;
  mixinStringBcast ~= "void bcastParameters() {\n";
  mixinStringBcast ~= "  writeLogRI(\"Distributing parameter set through MPI_Bcast.\");";

  foreach(fullModuleName ; parameterSourceModules) {
    immutable string qualModuleName = fullModuleName.split(".")[1..$].join();
    mixinStringShow ~= "  writeLog!(vl, logRankFormat)(\"\n[%s]\",\""~qualModuleName~"\");";

    foreach(e ; __traits(derivedMembers, mixin(fullModuleName))) {
      mixin(`
      static if ( __traits(compiles, __traits(getAttributes, `~fullModuleName~`.`~e~`))) {
        foreach( t; __traits(getAttributes, `~fullModuleName~`.`~e~`)) {
          if ( t == "`~parameterUDA~`" ) {
            auto fullName = "`~fullModuleName~`." ~ e;
            auto qualName = "`~qualModuleName~`." ~ e;

            mixinStringParser ~= "case \""~qualName~"\":\n";
            static if ( isMutable!(typeof(`~fullModuleName~`.`~e~`)) ) {
              mixinStringParser ~= "  if ( setParams.canFind(\""~fullName~"\") ) {\n";
              mixinStringParser ~= "    writeLogRW(\"Parameter '"~qualName~"' is set more than once, later declations are ignored.\");\n";
              mixinStringParser ~= "  }\n";
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
              mixinStringShow ~= "  if ( ! ( setParams.canFind(\""~fullName~"\") ) ) {\n";
              mixinStringShow ~= "    writeLog!(VL.Warning, logRankFormat)(\"! %-20s = %s\",\"`~e~`\",to!string("~fullName~"));\n";
              mixinStringShow ~= "  }\n  else {\n";
              mixinStringShow ~= "    writeLog!(vl, logRankFormat)(\"  %-20s = %s\",\"`~e~`\",to!string("~fullName~"));\n";
              mixinStringShow ~= "  }\n";
            }
            else {
              mixinStringShow ~= "  writeLog!(vl, logRankFormat)(\"x %-20s = %s\",\"`~e~`\",to!string("~fullName~"));\n";
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
        }
      }`);
    }
  }
  mixinStringParser ~= "default:\n  writeLogRW(\"Unknown key at line %d: '%s'.\", ln, keyString);\n}\n\n";
  mixinStringParser ~= "}\n";

  mixinStringShow ~= "  writeLog!(vl, logRankFormat)(\"\n\");\n}\n";

  mixinStringBcast ~= "}\n";

  return mixinStringParser ~ "\n" ~ mixinStringShow ~ "\n" ~ mixinStringBcast;

}

/**
   Creates an string mixin to import the modules specified in $(D parameterSourceModules).
*/
private auto createImports() {
  string mixinString;

  foreach(fullModuleName ; parameterSourceModules) {
    mixinString ~= "import " ~ fullModuleName ~ ";";
  }
  return mixinString;
}

