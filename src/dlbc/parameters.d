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

   lattice.gn = [32, 32, 32]   // Fully qualified parameter name

   [parallel]         // This is a section header
   ncy = 2            // This now corresponds to parallel.ncy

   [lattice]
   gn = [32, 32, 32]  // Later versions of the same parameter cause a warning

   []                 // This is a bit dirty, but actually resets the section name
   parallel.ncy = 2   // So now one needs to use fully qualified names again

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

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.parameters;

import std.conv;
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
   Lines of the input files.
*/
string[] inputFileData;

/**
   The UDA to be used to denote a parameter variable.
*/
static immutable string parameterUDA = "param";

/**
   A list of modules that have to be scanned for parameters.

   Bugs:
     Ideally this should be a template parameter to the createParameterMixins function, maybe?
*/
private alias parameterSourceModules = TypeTuple!(
                         "dlbc.lattice",
                         "dlbc.lb.lb",
                         "dlbc.lb.init",
                         "dlbc.lb.force",
                         "dlbc.lb.mask",
                         "dlbc.lb.thermal",
                         "dlbc.parallel",
                         "dlbc.random",
                         "dlbc.io.checkpoint",
                         "dlbc.io.io",
                         "dlbc.io.hdf5",
                         );
/**
   List of parameters that have been set in the input files.
*/
private string[] setParams;

void initParameters() {
  // Read, broadcast, and show parameters.
  if (M.isRoot) {
    readParameterSetFromCliFiles();
  }
  broadcastParameters();
  showParameters!(VL.Information, LRF.Root)();

  // Set secondary values based on parameters.
  processParameters();
}

/**
   Loops over all specified parameter files $(D parameterFileNames) in order to parse them.
   If no files are specified, a fatal error is logged.
*/
private void readParameterSetFromCliFiles() {
  if (parameterFileNames.length == 0) {
    writeLogRF("Parameter filename not set, please specify using the -p <filename> option.");
  }
  foreach(immutable fileName; parameterFileNames) {
    if ( fileName[$-3..$] == ".h5" ) {
      readParameterSetFromHdf5File(fileName);
    }
    else {
      readParameterSetFromTextFile(fileName);
    }
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
private void parseParameterLine(char[] line, const size_t ln, ref string currentSection) {
  import std.string;
  char[] keyString, valueString;

  enum vl = VL.Notification;
  enum logRankFormat = LRF.Root;

  immutable commentPos = indexOf(line, "//");
  if (commentPos >= 0) {
    line = line[0 .. commentPos];
  }

  immutable assignmentPos = indexOf(line, "=");
  if (assignmentPos > 0) {
    keyString = strip(line[0 .. assignmentPos]);
    valueString = strip(line[(assignmentPos+1) .. $]);
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
   Check if the length of a vector is appropriate. If it isn't, and strict is set to true,
   log a fatal error. Otherwise, assume zero for all elements if the element has length zero.

   Params:
     vector = vector to check
     name = name to report in case of fatal error
     len = required length
     strict = whether or not a zero-length vector is a fatal error
*/
void checkArrayParameterLength(T)(ref T vector, const string name, const size_t len, bool strict = false) {
  import dlbc.range: BaseElementType;

  if ( vector.length == 0 ) {
    if ( strict ) {
      writeLogF("Array parameter %s must have length %d.", name, len);
    }
    else {
      vector.length = len;
      static if ( is ( typeof(vector[0]) == string )) {
        writeLogRW("Array parameter %s has zero length, initialising to empty strings.", name);
        vector[] = "";
      }
      else {
        writeLogRW("Array parameter %s has zero length, initialising to zeros.", name);
        vector[] = cast(BaseElementType!T) 0;
      }
    }
  }
  else if ( vector.length != len ) {
    writeLogF("Array parameter %s must have length %d.", name, len);
  }
}

/**
   Attempt to parse a single ascii input file.

   Params:
     fileName = name of the file to be parsed
*/
private void readParameterSetFromTextFile(const string fileName) {
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
    auto line = f.readLine();
    inputFileData ~= to!string(line);
    parseParameterLine(line,++ln,currentSection);
  }
  f.close();
}

/**
   Attempt to extract an input file from an HDF5 file.

   Params:
     fileName = name of the file to be parsed
*/
private void readParameterSetFromHdf5File(const string fileName) {
  import std.file;
  import std.stream;

  string currentSection;
  writeLogRI("Extracting parameters from file '%s'.",fileName);

  auto lines = readInputFileAttributes(fileName);

  foreach(immutable ln, line; lines ) {
    inputFileData ~= line;
    char[] cline = line.dup;
    parseParameterLine(cline,ln,currentSection);
  }
}

private static bool isParameter (string variable)() {
  import std.typetuple;
  alias attrs = TypeTuple!(__traits(getAttributes, mixin(variable)));
  return staticIndexOf!(Exchange, attrs) != -1;
}

/**
   Creates an string mixin to define $(D parseParameter), $(D showParameters), and $(D bcastParameters).
*/
private auto createParameterMixins() {
  string mixinStringParser;
  string mixinStringShow;
  string mixinStringBcast;

  foreach(fullModuleName ; parameterSourceModules) {
    immutable string qualModuleName = makeQualModuleName(fullModuleName);
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
              mixinStringParser ~= "  catch (ConvException e) { writeLogF(\"ConvException at line %d of the input file: `~qualModuleName~`.`~e~` = %s.\",ln, valueString); throw e; }\n";
              mixinStringParser ~= "  setParams ~= \""~fullName~"\"; break;\n";
            }
            else {
              mixinStringParser ~= "  writeLogRW(\"Parameter '"~qualName~"' is not mutable.\");\n";
            }
            mixinStringParser ~= "\n";

            static if ( isMutable!(typeof(`~fullModuleName~`.`~e~`)) ) {
              mixinStringShow ~= "  if ( M.isRoot() && ( ! setParams.canFind(\""~fullName~"\") ) ) {\n";
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
              mixinStringBcast ~= "  broadcastParameter(`~fullModuleName~`.`~e~`);\n";
            }
          break;
          }
        }
      }`);
    }
  }
  return [ mixinStringParser, mixinStringShow, mixinStringBcast ];
}

/**
   Stores the mixins used below.
*/
private immutable parameterMixins = createParameterMixins();

/**
   Attempt to parse a single parameter, by converting it to the correct datatype and assigning the result to its matching variable.

   Params:
     keyString = qualified name of the parameter
     valueString = value to be assigned
     ln = line number (for more useful warnings)
*/
private void parseParameter(const string keyString, const string valueString, const size_t ln) {
  import std.algorithm;
  switch(keyString) {
    mixin(parameterMixins[0]);
  default:
    writeLogRW("Unknown key at line %d: '%s'.", ln, keyString);
  }
}

/**
   Show the current parameter set.

   Params:
     vl = verbosity level to write at
     logRankFormat = which processes should write
*/
void showParameters(VL vl, LRF logRankFormat)() {
  import std.algorithm;
  writeLog!(vl, logRankFormat)("Current parameter set:");
  mixin(parameterMixins[1]);
  writeLog!(vl, logRankFormat)("\n");
}

/**
   Broadcast all parameters from the root process to all other processes.
*/
private void broadcastParameters() {
  int arrlen;
  writeLogRI("Distributing parameter set through MPI_Bcast.");
  mixin(parameterMixins[2]);
}

/**
   Creates an string to set a parameter without having to repeat the module name
   if it is the same as the previous name in the module structure.

   Params:
     fullModuleName = full name of the module, including duplication

   Returns: name of the module without duplication

   Example:
   ---
   [io]
   outputFormat = HDF5 // This is actually io.io.outputFormat
   ---
*/
private auto makeQualModuleName(const string fullModuleName) {
  import std.string;
  auto splitModuleName = fullModuleName.split(".")[1..$];
  while ( (splitModuleName.length > 1) && (splitModuleName[$-1] == splitModuleName[$-2] ) ) {
    splitModuleName = splitModuleName[0..$-1];
  }
  return splitModuleName.join(".");
}

/**
   Creates an string mixin to import the modules specified in $(D parameterSourceModules).
*/
private auto createImports() {
  string mixinString;
  foreach(immutable fullModuleName ; parameterSourceModules) {
    mixinString ~= "import " ~ fullModuleName ~ ";";
  }
  return mixinString;
}

void setParameter(T)(ref T parameter, T value) {
  parameter = value;
  broadcastParameter(parameter);
}

