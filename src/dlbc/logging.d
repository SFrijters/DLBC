// Written in the D programming language.

/**
   Functions that handle (parallel) output to stdout.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.logging;

import std.conv;

version(D_Coverage) {
  // For code coverage, execute all the logging, but squelch the actual output.
  void writeln(T...)(T args) { }
}
else {
  import std.stdio: writeln;
}
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
}
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
}
/// Ditto
alias VL = VerbosityLevel;

version(unittest) {
  private VL globalVerbosityLevel = VL.Off;
}
else {
  private VL globalVerbosityLevel = VL.Debug;
}

/**
   Setter function for the global verbosity level.

   Params:
     newVL = new verbosity level
*/
void setGlobalVerbosityLevel(in VL newVL) @safe nothrow {
  globalVerbosityLevel = newVL;
}

/**
   Getter function for the global verbosity level.

   Returns: the current global verbosity level
*/
VL getGlobalVerbosityLevel() @safe nothrow {
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
void writeLog(VL vl, LRF logRankFormat, bool wrapLines = true, T...)(in T args) {
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
                if ( (!outString.canFind("\n") ) && ( outString.length > columnWidth) && wrapLines ) {
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
void writeLogRF(T...)(in T args) { writeLog!(VL.Fatal       , LRF.Root)(args); }
/// Ditto
void writeLogRE(T...)(in T args) { writeLog!(VL.Error       , LRF.Root)(args); }
/// Ditto
void writeLogRW(T...)(in T args) { writeLog!(VL.Warning     , LRF.Root)(args); }
/// Ditto
void writeLogRN(T...)(in T args) { writeLog!(VL.Notification, LRF.Root)(args); }
/// Ditto
void writeLogRI(T...)(in T args) { writeLog!(VL.Information , LRF.Root)(args); }
/// Ditto
void writeLogRD(T...)(in T args) { writeLog!(VL.Debug       , LRF.Root)(args); }

/// Ditto
void writeLogF(T...)(in T args)  { writeLog!(VL.Fatal       , LRF.Any )(args); }
/// Ditto
void writeLogE(T...)(in T args)  { writeLog!(VL.Error       , LRF.Any )(args); }
/// Ditto
void writeLogW(T...)(in T args)  { writeLog!(VL.Warning     , LRF.Any )(args); }
/// Ditto
void writeLogN(T...)(in T args)  { writeLog!(VL.Notification, LRF.Any )(args); }
/// Ditto
void writeLogI(T...)(in T args)  { writeLog!(VL.Information , LRF.Any )(args); }
/// Ditto
void writeLogD(T...)(in T args)  { writeLog!(VL.Debug       , LRF.Any )(args); }

/**
   Write output to stdout from all processes, gathered by the root process and ordered by process rank.

   Params:
     vl = verbosity level to write at
     args = data to write
*/
void owriteLog(VL vl, T...)(in T args) {
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
      foreach(immutable srcRank; 1..M.size ) {
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
void owriteLogF(T...)(in T args) { owriteLog!(VL.Fatal)(args); }
/// Ditto
void owriteLogE(T...)(in T args) { owriteLog!(VL.Error)(args); }
/// Ditto
void owriteLogW(T...)(in T args) { owriteLog!(VL.Warning)(args); }
/// Ditto
void owriteLogN(T...)(in T args) { owriteLog!(VL.Notification)(args); }
/// Ditto
void owriteLogI(T...)(in T args) { owriteLog!(VL.Information)(args); }
/// Ditto
void owriteLogD(T...)(in T args) { owriteLog!(VL.Debug)(args); }

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

  immutable string rankTag = makeRankString!logRankFormat();
  immutable string vlTag = makeVLString!vl();

  // Add time, if requested.
  string timeTag;
  if ( showTime ) {
    timeTag = makeCurrTimeString() ~ " ";
  }

  // Move any leading newlines in front of the tags.
  string preTag;
  while (args[0].length > 0 && args[0][0..1] == "\n") {
    preTag ~= args[0][0..1];
    args[0] = args[0][1..$];
  }

  if (args[0].length == 0 ) {
    return "";
  }

  args[0] = preTag ~ timeTag ~ vlTag ~ rankTag ~ args[0];

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
private string makeRankString(LogRankFormat logRankFormat)() @safe {
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

private string makeVLString(VerbosityLevel vl)() @safe pure nothrow @nogc {
  final switch(vl) {
  case VL.Off:
    return "[-] ";
  case VL.Fatal:
    return "[F] ";
  case VL.Error:
    return "[E] ";
  case VL.Warning:
    return "[W] ";
  case VL.Notification:
    return "[N] ";
  case VL.Information:
    return "[I] ";
  case VL.Debug:
    return "[D] ";
  }
}

/**
   Creates a formatted string containing the current time.

   Returns: a formatted string containing the current time.
*/
string makeCurrTimeString() {
  import std.datetime;

  SysTime tNow = Clock.currTime();
  return format("%#2.2d:%#2.2d:%#2.2d", tNow.hour, tNow.minute, tNow.second);
}

/**
   Creates a string with formatted $(D args) centered in a header line.

   Params:
     args = data to make into a header

   Returns: a string with formatted $(D args) centered in a header line.
*/
string makeHeaderString(T...)(in T args) pure {
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
string makeLengthsString(T : size_t)(in T[] lengths) @safe pure {
  string str;
  if ( lengths.length > 1 ) {
    foreach( l ; lengths ) {
      if ( str.length > 0 ) {
        str ~= " x ";
      }
      str ~= format("%d",l);
    }
  }
  else if ( lengths.length == 1 ) {
    str = format("length %d", lengths[0]);
  }
  else {
    assert(0);
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
  void writeLogURW(T...)(in T args) {
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
  @trusted nothrow void dwriteLog(VL vl, LRF logRankFormat, T...)(in T args) {
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
  void dwriteLogRF(T...)(in T args) { dwriteLog!(VL.Fatal       , LRF.Root)(args); }
  /// Ditto
  void dwriteLogRE(T...)(in T args) { dwriteLog!(VL.Error       , LRF.Root)(args); }
  /// Ditto
  void dwriteLogRW(T...)(in T args) { dwriteLog!(VL.Warning     , LRF.Root)(args); }
  /// Ditto
  void dwriteLogRN(T...)(in T args) { dwriteLog!(VL.Notification, LRF.Root)(args); }
  /// Ditto
  void dwriteLogRI(T...)(in T args) { dwriteLog!(VL.Information , LRF.Root)(args); }
  /// Ditto
  void dwriteLogRD(T...)(in T args) { dwriteLog!(VL.Debug       , LRF.Root)(args); }

  /// Ditto
  void dwriteLogF(T...)(in T args)  { dwriteLog!(VL.Fatal       , LRF.Any )(args); }
  /// Ditto
  void dwriteLogE(T...)(in T args)  { dwriteLog!(VL.Error       , LRF.Any )(args); }
  /// Ditto
  void dwriteLogW(T...)(in T args)  { dwriteLog!(VL.Warning     , LRF.Any )(args); }
  /// Ditto
  void dwriteLogN(T...)(in T args)  { dwriteLog!(VL.Notification, LRF.Any )(args); }
  /// Ditto
  void dwriteLogI(T...)(in T args)  { dwriteLog!(VL.Information , LRF.Any )(args); }
  /// Ditto
  void dwriteLogD(T...)(in T args)  { dwriteLog!(VL.Debug       , LRF.Any )(args); }
}

unittest {
  version(D_Coverage) {
    import std.conv: to;
    globalVerbosityLevel = VL.Debug;
    writeLogRD("Test %d", 1);
    writeLogRI("Test ", to!string(2));
    writeLogRN("Test " ~ "3");
    writeLogW("Test " ~ "4");
    owriteLogE("Test " ~ "5");
    globalVerbosityLevel = VL.Off;
  }
}

