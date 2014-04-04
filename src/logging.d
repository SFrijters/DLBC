import std.conv;
import std.stdio;
import std.string;

import parallel;

private immutable string truncationSuffix = "[T]...";
private immutable size_t headerLength = 80;
private immutable string headerDash = "=";

alias LogRankFormat LRF;
enum LogRankFormat {
  None    = 0,
  Root    = 1,
  Any     = 2,
  Ordered = 3,
};

alias VerbosityLevel VL;
enum VerbosityLevel {
  Off          = 0,
  Fatal        = 1,
  Error        = 2,
  Warning      = 3,
  Notification = 4,
  Information  = 5,
  Debug        = 6,
};

private VL globalVerbosityLevel = VL.Debug;

void setGlobalVerbosityLevel(const VL newVL) {
  writeLogRN("Setting globalVerbosityLevel to %d ('%s').", newVL, to!string(newVL));
  globalVerbosityLevel = newVL;
}

VL getGlobalVerbosityLevel() {
  return globalVerbosityLevel;
}

void writeLog(T...)(const VL vl, const LRF logRankFormat, const T args) {
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
	  string outString = makeLogString(vl, logRankFormat, args);
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
		writefln(strip(outString));
	      }
	    }
	    return;
	  }
	}
	// not a string, or not a formatted string
	writeln(args);
      }
    }
    break;
  case LRF.Ordered:
    owriteLog(vl, args);
    break;
  }
}

void writeLogRF(T...)(const T args) { writeLog(VL.Fatal       , LRF.Root, args); }
void writeLogRE(T...)(const T args) { writeLog(VL.Error       , LRF.Root, args); }
void writeLogRW(T...)(const T args) { writeLog(VL.Warning     , LRF.Root, args); }
void writeLogRN(T...)(const T args) { writeLog(VL.Notification, LRF.Root, args); }
void writeLogRI(T...)(const T args) { writeLog(VL.Information , LRF.Root, args); }
void writeLogRD(T...)(const T args) { writeLog(VL.Debug       , LRF.Root, args); }

void writeLogF(T...)(const T args)  { writeLog(VL.Fatal       , LRF.Any,  args); }
void writeLogE(T...)(const T args)  { writeLog(VL.Error       , LRF.Any,  args); }
void writeLogW(T...)(const T args)  { writeLog(VL.Warning     , LRF.Any,  args); }
void writeLogN(T...)(const T args)  { writeLog(VL.Notification, LRF.Any,  args); }
void writeLogI(T...)(const T args)  { writeLog(VL.Information , LRF.Any,  args); }
void writeLogD(T...)(const T args)  { writeLog(VL.Debug       , LRF.Any,  args); }

/// Ordered logwrite from all CPUs
void owriteLog(T...)(const VL vl, const T args) {
  string logString;
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
    logString = makeLogString(vl, LRF.Ordered, args);

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

void owriteLogF(T...)(const T args) { owriteLog(VL.Fatal       , args); }
void owriteLogE(T...)(const T args) { owriteLog(VL.Error       , args); }
void owriteLogW(T...)(const T args) { owriteLog(VL.Warning     , args); }
void owriteLogN(T...)(const T args) { owriteLog(VL.Notification, args); }
void owriteLogI(T...)(const T args) { owriteLog(VL.Information , args); }
void owriteLogD(T...)(const T args) { owriteLog(VL.Debug       , args); }

private string makeLogString(T...)(const VL vl, const LRF logRankFormat, T args) {
  import std.algorithm: canFind;

  immutable string rankTag = makeRankString(logRankFormat);
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
  while (args[0][0..1] == "\n") {
    preTag ~= args[0][0..1];
    args[0] = args[0][1..$];
  }

  args[0] = preTag ~ vlTag ~ rankTag ~ args[0];

  if (canFind(args[0], "%")) {
    return format(args);
  }
  else {
    return args[0];
  }
}

private string makeRankString(const LogRankFormat logRankFormat) {
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

string makeCurrTimeString() {
  import std.datetime;

  SysTime tNow = Clock.currTime;
  return format("%#2.2d:%#2.2d:%#2.2d", tNow.hour, tNow.minute, tNow.second);
}

string makeHeaderString(const string content) pure nothrow {
  import std.array: replicate;

  if (content.length >= headerLength - 4) {
    return content;
  }

  string headerString;

  size_t dashLength = headerLength - content.length - 2;
  size_t preLength = dashLength/2 + dashLength%2;
  size_t sufLength = dashLength/2;

  string preDash = replicate(headerDash, preLength);
  string sufDash = replicate(headerDash, sufLength);
  
  headerString = "\n" ~ preDash ~ " " ~ content ~ " " ~ sufDash ~ "\n";

  return headerString;
}

