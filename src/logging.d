import std.array;
import std.conv;
import std.stdio;
import std.datetime;
import std.string;
import std.algorithm;

import parallel;
import revision;

immutable string truncationSuffix = "[T]...";
immutable ulong headerLength = 80;
immutable string headerDash = "=";

alias LogRankFormat LRF;
enum LogRankFormat {
  None    = 0,
  Root    = 1,
  Any     = 2,
  Ordered = 3
};

alias VerbosityLevel VL;
enum VerbosityLevel {
  Off          = 0,
  Fatal        = 1,
  Error        = 2,
  Warning      = 3,
  Notification = 4,
  Information  = 5,
  Debug        = 6
};

VL globalVerbosityLevel = VL.Debug;

void owriteLogF(T...)(T args) { owriteLog(VL.Fatal       , args); }
void owriteLogE(T...)(T args) { owriteLog(VL.Error       , args); }
void owriteLogW(T...)(T args) { owriteLog(VL.Warning     , args); }
void owriteLogN(T...)(T args) { owriteLog(VL.Notification, args); }
void owriteLogI(T...)(T args) { owriteLog(VL.Information , args); }
void owriteLogD(T...)(T args) { owriteLog(VL.Debug       , args); }

/// Ordered logwrite from all CPUs
void owriteLog(T...)(VL vl, T args) {
  string logString;
  MpiString mpiString;
  MPI_Status mpiStatus;
  immutable int mpiTag = 0;

  if (globalVerbosityLevel >= vl) {

    // Fill mpiString with spaces
    for(int i = 0; i < MpiStringLength; i++) {
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
    if (M.rank == M.root) {
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
  }
}

void writeLogRF(T...)(T args) { if (M.rank == M.root) writeLog(VL.Fatal       , LRF.Root, args); }
void writeLogRE(T...)(T args) { if (M.rank == M.root) writeLog(VL.Error       , LRF.Root, args); }
void writeLogRW(T...)(T args) { if (M.rank == M.root) writeLog(VL.Warning     , LRF.Root, args); }
void writeLogRN(T...)(T args) { if (M.rank == M.root) writeLog(VL.Notification, LRF.Root, args); }
void writeLogRI(T...)(T args) { if (M.rank == M.root) writeLog(VL.Information , LRF.Root, args); }
void writeLogRD(T...)(T args) { if (M.rank == M.root) writeLog(VL.Debug       , LRF.Root, args); }

void writeLogF(T...)(T args) { writeLog(VL.Fatal       , LRF.Any, args); }
void writeLogE(T...)(T args) { writeLog(VL.Error       , LRF.Any, args); }
void writeLogW(T...)(T args) { writeLog(VL.Warning     , LRF.Any, args); }
void writeLogN(T...)(T args) { writeLog(VL.Notification, LRF.Any, args); }
void writeLogI(T...)(T args) { writeLog(VL.Information , LRF.Any, args); }
void writeLogD(T...)(T args) { writeLog(VL.Debug       , LRF.Any, args); }

void writeLog(T...)(VL vl, LRF logRankFormat, T args) {

  if (globalVerbosityLevel >= vl) {

    static if (!T.length) {
      writeln();
    }
    else {
      static if (is(T[0] : string)) {
	string outString = makeLogString(vl, logRankFormat, args);
	if (outString.length != 0) {
	  writefln(outString);
	  return;
	}
      }
      // not a string, or not a formatted string
      writeln(args);
    }
  }
}

string makeLogString(T...)(VL vl, LRF logRankFormat, T args) {
  string logString;
  string rankTag = makeRankString(logRankFormat);
  string vlTag;
  string preTag;

  final switch(vl) {
  case VL.Off:          vlTag = "[-] "; break;
  case VL.Fatal:        vlTag = "[F] "; break;
  case VL.Error:        vlTag = "[E] "; break;
  case VL.Warning:      vlTag = "[W] "; break;
  case VL.Notification: vlTag = "[N] "; break;
  case VL.Information:  vlTag = "[I] "; break;
  case VL.Debug:        vlTag = "[D] "; break;
  }

  // Move any leading newlines in front of the tags.
  while (args[0][0..1] == "\n") {
    preTag ~= args[0][0..1];
    args[0] = args[0][1..$];
  }

  args[0] = preTag ~ vlTag ~ rankTag ~ args[0];

  if (canFind(args[0], "%")) {
    logString = format(args);
  }
  else {
    logString = args[0];
  }

  return logString;
}

string makeRankString(LogRankFormat logRankFormat) {
  string rankString;

  final switch(logRankFormat) {
    case LRF.None:    rankString = ""; break;
    case LRF.Root:    rankString = ""; break;
    case LRF.Any:     rankString = format("[%#6.6d] ",M.rank); break;
    case LRF.Ordered: rankString = format("<%#6.6d> ",M.rank); break;
  }

  return rankString;
}

string makeTimeString() {
  SysTime tNow = Clock.currTime;
  string timeString = format("%#2.2d:%#2.2d:%#2.2d",tNow.hour,tNow.minute,tNow.second);

  return timeString;
}

string makeHeaderString(string content) {
  if (content.length >= headerLength - 4) {
    return content;
  }

  string headerString;

  ulong dashLength = headerLength - content.length - 2;
  ulong preLength = dashLength/2 + dashLength%2;
  ulong sufLength = dashLength/2;

  string preDash = replicate(headerDash, preLength);
  string sufDash = replicate(headerDash, sufLength);
  
  headerString = "\n" ~ preDash ~ " " ~ content ~ " " ~ sufDash ~ "\n";

  return headerString;
}

void setGlobalVerbosityLevel(VL newVL) {
  writeLogRN("Setting globalVerbosityLevel to %d (%s).", newVL, to!string(newVL));
  globalVerbosityLevel = newVL;
}

void showRevisionInfo() {
  if (revisionChanges.length == 0) {
    writeLogRI("Executable built from revision %s .", revisionNumber );
  }
  else {
    writeLogRI("Executable built from revision %s (with local changes).", revisionNumber );
    writeLogRD("  Changes from HEAD: %s.\n", revisionChanges );
  }
}
