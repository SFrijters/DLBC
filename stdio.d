import std.stdio;
import std.datetime;
import std.string;
import std.algorithm;

import mpi;

void writelog(T...)(T args) {
  static if (!T.length) {
    writeln();
  }
  else {
    static if (is(T[0] : string)) {
      SysTime tNow = Clock.currTime;
      string prefix = format("%#2.2d:%#2.2d:%#2.2d",tNow.hour,tNow.minute,tNow.second);
      string rank = format("<%#6.6d> ",M.rank);
      args[0] = prefix ~ " [TEST] " ~ rank ~ args[0];
      if (canFind(args[0], "%")) {
	writefln(args);
	return;
      }
    }
    // not a string, or not a formatted string
    writeln(args);
  }
}

