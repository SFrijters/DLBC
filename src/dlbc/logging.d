// Written in the D programming language.

/**
Functions that handle (parallel) output to stdout.

Copyright: Stefan Frijters 2011-2014

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

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

bool warningsAreFatal = false;

/**
   String to append to truncated messages.
*/
private shared immutable string truncationSuffix = "[T]...";
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
alias LogRankFormat LRF;

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
alias VerbosityLevel VL;

private VL globalVerbosityLevel = VL.Debug;

/**
   Setter function for the global verbosity level.

   Params:
     newVL = new verbosity level
*/
void setGlobalVerbosityLevel(const VL newVL) {
  writeLogRN("Setting globalVerbosityLevel to %d ('%s').", newVL, to!string(newVL));
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
		writefln(outString);
	      }
	      else {
		writefln(stripLeft(outString));
	      }
	    }
	    else {
	      if (outString[0..1] == "\n" ) {	      
		writefln(stripRight(outString));
	      }
	      else {
		if ( ! outString.canFind("\n") ) {
		  outString = stripRight(wrap(outString, columnWidth, null, indent));
		}
		writefln(strip(outString));
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

   Bugs: Possible memory issues causing corrupted data or hanging processes.
*/
void owriteLog(VL vl, T...)(const T args) {
  //return;
  string logString;
  char[17] test1; // WUT?
  MpiString mpiString;
  MPI_Status mpiStatus;
  immutable int mpiTag = 0;

  if (globalVerbosityLevel >= vl) {

    // Make sure all other stdout is flushed. Performance hog!
    MpiBarrier();

    // Fill mpiString with spaces
    for(size_t i = 0; i < MpiStringLength; i++) {
      mpiString[i] = ' ';
    }

    // Generate string to send
    logString = makeLogString!(vl, LRF.Ordered)(args);

    // Truncate if needed
    if (logString.length > MpiStringLength) {
      logString = logString[0 .. MpiStringLength - truncationSuffix.length] ~ truncationSuffix;
    }

    // Overwrite the first part of mpiString with the actual payload
    mpiString[0 .. logString.length] = logString;

    // Convert the char[256] to string, strip the spaces, and print it
    if (M.isRoot) {
      logString = to!string(mpiString);
      writeln(strip(logString));
      for (int srcRank = 1; srcRank < M.size; srcRank++ ) {

	MPI_Recv(&mpiString, MpiStringLength, MPI_CHAR, srcRank, mpiTag, M.comm, &mpiStatus);
	logString = to!string(mpiString);
	writeln(strip(logString));
      }
    }
    else {
      immutable int destRank = M.root;
      MPI_Send(&mpiString, MpiStringLength, MPI_CHAR, destRank, mpiTag, M.comm);
    }

    // Make sure all ordered output is finished before the program continues. Performance hog!
    MpiBarrier();
  }
}

/**
   Shorthand for various ordered logging templates based on $(D owriteLog).

   The last letter of the function name corresponds to the first of the verbosity level enum member that is passed into the template.

   Params:
     args = data to write
*/
void owriteLogF(T...)(const T args) { owriteLog(VL.Fatal       , args); }
/// Ditto
void owriteLogE(T...)(const T args) { owriteLog(VL.Error       , args); }
/// Ditto
void owriteLogW(T...)(const T args) { owriteLog(VL.Warning     , args); }
/// Ditto
void owriteLogN(T...)(const T args) { owriteLog(VL.Notification, args); }
/// Ditto
void owriteLogI(T...)(const T args) { owriteLog(VL.Information , args); }
/// Ditto
void owriteLogD(T...)(const T args) { owriteLog(VL.Debug       , args); }

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
string makeLengthsString(const uint[] lengths) pure {
  string str;
  foreach( l ; lengths ) {
    if ( str.length > 0 ) {
      str ~= " x ";
    }
    str ~= format("%d",l);
  }
  return str;
}

