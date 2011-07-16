import std.conv;
import std.stdio;
import std.datetime;
import std.string;
import std.algorithm;

import mpi;
import parallel;

const string truncationSuffix = "[T]...";

void owritelog(T...)(T args) {
  string logString;
  MpiString mpiString;
  MPI_Status status;

  // Fill mpiString with spaces
  for(int i = 0; i < MpiStringLength; i++) {
     mpiString[i] = ' ';
  }

  // Generate string to send
  logString = logstr(args);

  // Truncate if needed
  if (logString.length > MpiStringLength) {
    logString = logString[0 .. MpiStringLength - truncationSuffix.length] ~ truncationSuffix;
  }

  // Overwrite the first part of mpiString with the actual payload
  mpiString[0 .. logString.length] = logString;

  // Convert the char[256] to string, strip the spaces, and print it
  if (M.rank == 0) {
    logString = to!string(mpiString);
    writeln(strip(logString));
    for (int src = 1; src < M.size; src++ ) {
      MPI_Recv(&mpiString, MpiStringLength, MPI_CHAR, src, 0, M.comm, &status);
      logString = to!string(mpiString);
      writeln(strip(logString));
    }
  }
  else {
    MPI_Send(&mpiString, MpiStringLength, MPI_CHAR, 0, 0, M.comm);
  }
  
}

void writelog(T...)(T args) {
  static if (!T.length) {
    writeln();
  }
  else {
    static if (is(T[0] : string)) {
      string outString = logstr(args);
      if (outString.length != 0) {
	writefln(outString);
	return;
      }
    }
    // not a string, or not a formatted string
    writeln(args);
  }
}


string logstr(T...)(T args) {
  string outString;
  string rank;
  SysTime tNow = Clock.currTime;
  string prefix = format("%#2.2d:%#2.2d:%#2.2d",tNow.hour,tNow.minute,tNow.second);
  rank = format("<%#6.6d> ",M.rank);
  args[0] = prefix ~ " [TEST] " ~ rank ~ args[0];
  if (canFind(args[0], "%")) {
    outString = format(args);
  }
  return outString;
}
