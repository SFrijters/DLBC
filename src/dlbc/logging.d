// Written in the D programming language.

/**
   Functions that handle (parallel) output to stdout.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.logging;

import std.conv;
import std.stdio;
import std.string;

import dlbc.parallel;

/**
   Show the current time in the various writeLog functions.
*/
bool showTime = false;
/**
   If set, warnings and above are treated as fatal errors.
*/
bool warningsAreFatal = false;
/**
   Maximum width of the terminal output.
*/
private shared immutable size_t columnWidth = 120;
/**
   Indent for wrapped lines.
*/
private shared immutable string indent = "  > ";
/**
   Length of a header line.
*/
private shared immutable size_t headerLength = columnWidth - indent.length;
/**
   Character to fill the header line with.
*/
private shared immutable string headerDash = "=";
/**
   Names of dimensions.
*/
shared immutable string[] dimstr = [ "x", "y", "z" ];

/**
   Specifies which processes should do the logging when passed as a (template) argument to various logging functions.
*/
enum LogRankFormat {
  /**
     No output.
  */
  None    = 0,
  /**
     Only the root process will write output.
  */
  Root    = 1,
  /**
     Any process will write output.
  */
  Any     = 2,
  /**
     All processes will send their output to the root process, 
     which will display all output in order of process rank.
  */
  Ordered = 3,
};
/// Ditto
alias LRF = LogRankFormat;

/**
   Specifies at which verbosity level the logging should be executed when passed as a (template) argument to various logging functions.
*/
enum VerbosityLevel {
  /**
     No output.
  */
  Off          = 0,
  /**
     Log fatal errors only.
  */
  Fatal        = 1,
  /**
     Log errors and above only.
  */
  Error        = 2,
  /**
     Log warnings and above only.
  */
  Warning      = 3,
  /**
     Log notifications and above only.
  */
  Notification = 4,
  /**
     Log informational messages and above only.
  */
  Information  = 5,
  /**
     Log all output.
  */
  Debug        = 6,
};
/// Ditto
alias VL = VerbosityLevel;

version(unittest) {
  VL globalVerbosityLevel = VL.Off;
}
else {
  private VL globalVerbosityLevel = VL.Debug;
}

private VL squelchedGlobalVL;
private bool isSquelched = false;

void squelchLog() {
  if ( ! isSquelched ) {
    squelchedGlobalVL = globalVerbosityLevel;
    globalVerbosityLevel = VL.Off;
    isSquelched = true;
  }
}

void unsquelchLog() {
  globalVerbosityLevel = squelchedGlobalVL;
}

/**
   Setter function for the global verbosity level.

   Params:
     newVL = new verbosity level
*/
void setGlobalVerbosityLevel(const VL newVL) {
  globalVerbosityLevel = newVL;
}

/**
   Getter function for the global verbosity level.

   Returns: the current global verbosity level
*/
VL getGlobalVerbosityLevel() {
  return globalVerbosityLevel;
}

/**
   Report the global verbosity level.
*/
void showGlobalVerbosityLevel() {
  writeLogRN("globalVerbosityLevel is set to %d ('%s').", globalVerbosityLevel, to!string(globalVerbosityLevel));
}

/**
   Write output to stdout, depending on the verbosity level and which processes are allowed to write.

   Params:
     vl = verbosity level to write at
     logRankFormat = which processes should write
     args = data to write
*/
void writeLog(const VL vl, const LRF logRankFormat, T...)(const T args) {
  import std.algorithm: canFind;

  final switch(logRankFormat) {
  case LRF.None:
    break;
  case LRF.Root:
    if (!M.isRoot) break;
    goto case;
  case LRF.Any:
    if (globalVerbosityLevel >= vl) {
      static if (!T.length) {
	writeln();
      }
      else {
	static if (is(T[0] : string)) {
	  string outString = makeLogString!(vl, logRankFormat)(args);
	  if (outString.length != 0) {
	    if (outString[$-1..$] == "\n" ) {
	      if (outString[0..1] == "\n" ) {
		writeln(outString);
	      }
	      else {
		writeln(stripLeft(outString));
	      }
	    }
	    else {
	      if (outString[0..1] == "\n" ) {
		writeln(stripRight(outString));
	      }
	      else {
		if ( (!outString.canFind("\n") ) && ( outString.length > columnWidth) ) {
		  outString = stripRight(wrap(outString, columnWidth, null, indent));
		}
		writeln(strip(outString));
	      }
	    }
	    break;
	  }
	  else {
	    writeln();
	    break;
	  }
	}
	else {
	  // not a string, or not a formatted string
	  writeln(args);
	}
      }
    }
    break;
  case LRF.Ordered:
    owriteLog!(vl)(args);
    break;
  }

  // Abort conditions...
  import std.c.stdlib: exit;
  if ( vl == VL.Fatal ) {
    writeln(makeLogString!(vl, LRF.Any)("Fatal error, aborting..."));
    exit(-1);
  }
  if ( warningsAreFatal ) {
    if ( vl == VL.Error ) {
      writeln(makeLogString!(vl, LRF.Any)("Error treated as fatal error, aborting..."));
      exit(-1);
    }
    if ( vl == VL.Warning ) {
      writeln(makeLogString!(vl, LRF.Any)("Warning treated as fatal error, aborting..."));
      exit(-1);
    }
  }
}

/**
   Shorthand for various logging templates based on $(D writeLog).

   The last letter of the function name corresponds to the first of the verbosity level enum member that is passed into the template.
   The optional 'R' passes $(D LRF.Root), otherwise $(D LRF.Any) is passed.

   Params:
     args = data to write
*/
void writeLogRF(T...)(const T args) { writeLog!(VL.Fatal       , LRF.Root)(args); }
/// Ditto
void writeLogRE(T...)(const T args) { writeLog!(VL.Error       , LRF.Root)(args); }
/// Ditto
void writeLogRW(T...)(const T args) { writeLog!(VL.Warning     , LRF.Root)(args); }
/// Ditto
void writeLogRN(T...)(const T args) { writeLog!(VL.Notification, LRF.Root)(args); }
/// Ditto
void writeLogRI(T...)(const T args) { writeLog!(VL.Information , LRF.Root)(args); }
/// Ditto
void writeLogRD(T...)(const T args) { writeLog!(VL.Debug       , LRF.Root)(args); }

/// Ditto
void writeLogF(T...)(const T args)  { writeLog!(VL.Fatal       , LRF.Any )(args); }
/// Ditto
void writeLogE(T...)(const T args)  { writeLog!(VL.Error       , LRF.Any )(args); }
/// Ditto
void writeLogW(T...)(const T args)  { writeLog!(VL.Warning     , LRF.Any )(args); }
/// Ditto
void writeLogN(T...)(const T args)  { writeLog!(VL.Notification, LRF.Any )(args); }
/// Ditto
void writeLogI(T...)(const T args)  { writeLog!(VL.Information , LRF.Any )(args); }
/// Ditto
void writeLogD(T...)(const T args)  { writeLog!(VL.Debug       , LRF.Any )(args); }

/**
   Write output to stdout from all processes, gathered by the root process and ordered by process rank.

   Params:
     vl = verbosity level to write at
     args = data to write
*/
void owriteLog(VL vl, T...)(const T args) {
  enum mpiTag = 0;
  if (globalVerbosityLevel >= vl) {
    MPI_Status mpiStatus;
    // Generate string to send
    string logString = makeLogString!(vl, LRF.Ordered)(args);

    // Fill char buffer
    char[] strbuf;
    int strlen = to!int(logString.length);
    strbuf.length = strlen;
    strbuf[0..strlen] = logString;

    if (M.isRoot) {
      // First show the local log
      logString = to!string(strbuf[0..strlen]);
      writeln(strip(logString));
      for (int srcRank = 1; srcRank < M.size; srcRank++ ) {
	// Then receive from each process first a string length...
	MPI_Recv(&strlen, 1, MPI_INT, srcRank, mpiTag, M.comm, &mpiStatus);
        strbuf.length = strlen;
	// ...and then the char buffer.
	MPI_Recv(strbuf.ptr, strlen, MPI_CHAR, srcRank, mpiTag, M.comm, &mpiStatus);
	logString = to!string(strbuf[0..strlen]);
	writeln(strip(logString));
      }
    }
    else {
      immutable int destRank = M.root;
      MPI_Send(&strlen, 1, MPI_INT, destRank, mpiTag, M.comm);
      MPI_Send(strbuf.ptr, strlen, MPI_CHAR, destRank, mpiTag, M.comm);
    }
  }
}

/**
   Shorthand for various ordered logging templates based on $(D owriteLog).

   The last letter of the function name corresponds to the first of the verbosity level enum member that is passed into the template.

   Params:
     args = data to write
*/
void owriteLogF(T...)(const T args) { owriteLog!(VL.Fatal)(args); }
/// Ditto
void owriteLogE(T...)(const T args) { owriteLog!(VL.Error)(args); }
/// Ditto
void owriteLogW(T...)(const T args) { owriteLog!(VL.Warning)(args); }
/// Ditto
void owriteLogN(T...)(const T args) { owriteLog!(VL.Notification)(args); }
/// Ditto
void owriteLogI(T...)(const T args) { owriteLog!(VL.Information)(args); }
/// Ditto
void owriteLogD(T...)(const T args) { owriteLog!(VL.Debug)(args); }

/**
   Creates a string with a text marker for verbosity level prepended to $(D args).

   This function also takes care of leading newlines, which should create completely blank lines before the actual content is shown with the proper tag.

   Params:
     vl = verbosity level to use for the marker
     logRankFormat = log type to use for the process prefix
     args = data to write

   Returns: a string with a text marker for verbosity level prepended to $(D args).
*/
private string makeLogString(VL vl, LRF logRankFormat, T...)(T args) {
  import std.algorithm: canFind;

  immutable string rankTag = makeRankString!logRankFormat;
  string vlTag, preTag;

  final switch(vl) {
  case VL.Off:
    vlTag = "[-] ";
    break;
  case VL.Fatal:
    vlTag = "[F] ";
    break;
  case VL.Error:
    vlTag = "[E] ";
    break;
  case VL.Warning:
    vlTag = "[W] ";
    break;
  case VL.Notification:
    vlTag = "[N] ";
    break;
  case VL.Information:
    vlTag = "[I] ";
    break;
  case VL.Debug:
    vlTag = "[D] ";
    break;
  }

  if ( showTime ) {
    vlTag = makeCurrTimeString() ~ " " ~ vlTag;
  }

  // Move any leading newlines in front of the tags.
  while (args[0].length > 0 && args[0][0..1] == "\n") {
    preTag ~= args[0][0..1];
    args[0] = args[0][1..$];
  }

  if (args[0].length == 0 ) {
    return "";
  }

  args[0] = preTag ~ vlTag ~ rankTag ~ args[0];

  if (canFind(args[0], "%")) {
    return format(args);
  }
  else {
    return args[0];
  }
}

/**
   Creates a string prefix containing the current process rank, if applicable.

   Params:
     logRankFormat = log type to use for the rank prefix

   Returns: a string prefix containing the current process rank, if applicable.
*/
private string makeRankString(LogRankFormat logRankFormat)() {
  final switch(logRankFormat) {
  case LRF.None:
    return "";
  case LRF.Root:
    return "";
  case LRF.Any:
    return format("[%#6.6d] ", M.rank);
  case LRF.Ordered:
    return format("<%#6.6d> ", M.rank);
  }
}

/**
   Creates a formatted string containing the current time.

   Returns: a formatted string containing the current time.
*/
string makeCurrTimeString() {
  import std.datetime;

  SysTime tNow = Clock.currTime;
  return format("%#2.2d:%#2.2d:%#2.2d", tNow.hour, tNow.minute, tNow.second);
}

/**
   Creates a string with formatted $(D args) centered in a header line.

   Params:
     args = data to make into a header

   Returns: a string with formatted $(D args) centered in a header line.
*/
string makeHeaderString(T...)(const T args) pure {
  import std.algorithm: canFind;
  import std.array: replicate;

  static assert(headerDash.length == 1, "headerDash should be a single character." ); // Assumption for the code below.

  // Format the string if required.
  string formatted;
  if (canFind(args[0], "%")) {
    formatted = format(args);
  }
  else {
    formatted = args[0];
  }

  if (formatted.length >= headerLength - 4) {
    return formatted;
  }

  size_t dashLength = headerLength - formatted.length - 2;
  size_t preLength = dashLength/2 + dashLength%2;
  size_t sufLength = dashLength/2;

  string preDash = replicate(headerDash, preLength);
  string sufDash = replicate(headerDash, sufLength);

  return "\n" ~ preDash ~ " " ~ formatted ~ " " ~ sufDash ~ "\n";
}

/**
   Creates a string with the values in $(D lengths) separated by "x" to denote grid size.

   Params:
     lengths = array of lengths of arbitrary dimension

   Returns: a string with the values in $(D lengths) separated by "x" to denote grid size.
*/
string makeLengthsString(T : size_t)(const T[] lengths) pure {
  string str;
  foreach( l ; lengths ) {
    if ( str.length > 0 ) {
      str ~= " x ";
    }
    str ~= format("%d",l);
  }
  return str;
}

version(unittest) {
  /**
     Logging templates used for unittesting - temporarily removes the squelch.

     The last letter of the function name corresponds to the first of the verbosity level enum member that is passed into the template.
     The optional 'R' passes $(D LRF.Root), otherwise $(D LRF.Any) is passed.

     Params:
       args = data to write
  */
  void writeLogURW(T...)(const T args) {
    globalVerbosityLevel = VL.Debug;
    writeLog!(VL.Warning, LRF.Root)(args);
    globalVerbosityLevel = VL.Off;
  }
}

debug {
  /**
     Logging function for debugging purposes: @trusted to be allowed in safe code, nothrow to 
     be allowed in nothrow code, and purity is ignored when compiled with -debug.

     Params:
       vl = verbosity level to write at
       logRankFormat = which processes should write
       args = data to write
  */
  @trusted nothrow void dwriteLog(const VL vl, const LRF logRankFormat, T...)(const T args) {
    debug {
      import std.stdio;
      try {
	writeLog!(vl, logRankFormat)(args);
      }
      catch (Exception e) {
      }
    }
  }

  /**
     Shorthand for various logging templates based on $(D dwriteLog).

     The last letter of the function name corresponds to the first of the verbosity level enum member that is passed into the template.
     The optional 'R' passes $(D LRF.Root), otherwise $(D LRF.Any) is passed.

     Params:
       args = data to write
  */
  void dwriteLogRF(T...)(const T args) { dwriteLog!(VL.Fatal       , LRF.Root)(args); }
  /// Ditto
  void dwriteLogRE(T...)(const T args) { dwriteLog!(VL.Error       , LRF.Root)(args); }
  /// Ditto
  void dwriteLogRW(T...)(const T args) { dwriteLog!(VL.Warning     , LRF.Root)(args); }
  /// Ditto
  void dwriteLogRN(T...)(const T args) { dwriteLog!(VL.Notification, LRF.Root)(args); }
  /// Ditto
  void dwriteLogRI(T...)(const T args) { dwriteLog!(VL.Information , LRF.Root)(args); }
  /// Ditto
  void dwriteLogRD(T...)(const T args) { dwriteLog!(VL.Debug       , LRF.Root)(args); }

  /// Ditto
  void dwriteLogF(T...)(const T args)  { dwriteLog!(VL.Fatal       , LRF.Any )(args); }
  /// Ditto
  void dwriteLogE(T...)(const T args)  { dwriteLog!(VL.Error       , LRF.Any )(args); }
  /// Ditto
  void dwriteLogW(T...)(const T args)  { dwriteLog!(VL.Warning     , LRF.Any )(args); }
  /// Ditto
  void dwriteLogN(T...)(const T args)  { dwriteLog!(VL.Notification, LRF.Any )(args); }
  /// Ditto
  void dwriteLogI(T...)(const T args)  { dwriteLog!(VL.Information , LRF.Any )(args); }
  /// Ditto
  void dwriteLogD(T...)(const T args)  { dwriteLog!(VL.Debug       , LRF.Any )(args); }
}

