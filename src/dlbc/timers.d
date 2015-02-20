// Written in the D programming language.

/**
   Timers for performance measurement.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.timers;

import std.datetime;

import dlbc.logging;

private MSW[string] timersAA;

/**
   Enable writing the timing data to disk in raw ascii format.
*/
@("param") bool enableIO = false;

private immutable string fileNamePrefix = "timers";

void startTimer(VL vl = VL.Debug, LRF logRankFormat = LRF.None)(in string name) {
  if ( (name in timersAA) is null ) {
    timersAA[name] = MSW(name);
  }
  timersAA[name].start!(vl, logRankFormat)();
}

void stopTimer(VL vl = VL.Debug, LRF logRankFormat = LRF.None)(in string name) {
  assert( (name in timersAA) !is null );
  timersAA[name].stop!(vl, logRankFormat)();
}

/**
   Based on $(D StopWatch), a $(D MultiStopWatch) can be started and stopped multiple times, keeping track of how often it has been called.
*/
struct MultiStopWatch {
  private StopWatch single, multi;
  /**
     How many times the $(D MultiStopWatch) has been started.
  */
  int count;
  /**
     Name of the $(D MultiStopWatch).
  */
  string name;

  /**
     $(D MultiStopWatch) is constructed with a name.

     Params:
       n = name of the $(D MultiStopWatch)
  */
  this (string n) {
    name = n;
  }

  /**
     Peek into the embedded single run $(D StopWatch).

     Returns: a $(D TickDuration) struct.
  */
  auto peekSingle() {
    return single.peek();
  }

  /**
     Peek into the embedded multiple run $(D StopWatch).

     Returns: a $(D TickDuration) struct.
  */
  auto peekMulti() {
    return multi.peek();
  }

  /**
     Write the current status of the $(D MultiStopWatch) to stdout, depending on the verbosity level and which processes are allowed to write.

     Params:
       vl = verbosity level to write at
       logRankFormat = which processes should write
  */
  void show(VL vl, LRF logRankFormat)() {
    writeLog!(vl, logRankFormat)("Timer '%s' measuring run %d for %dms. Total runtime %dms.", name, count, single.peek().msecs, multi.peek().msecs);
  }

  /**
     Write the current status of the $(D MultiStopWatch) to stdout, depending on the verbosity level and which processes are allowed to write.

     Params:
       vl = verbosity level to write at
       logRankFormat = which processes should write
  */
  void showFinal(VL vl, LRF logRankFormat)() {
    import std.conv: to;
    if ( count > 0 ) {
      if ( ("main" in timersAA) !is null ) {
	double perc = 100.0 * to!double(multi.peek().msecs) / to!double(timersAA["main"].peekMulti().msecs);
	writeLog!(vl, logRankFormat)("Timer %16s was run %6d times. Total runtime %8dms (%6.2f%%), average runtime %8.0fms.", "'"~name~"'", count, multi.peek().msecs, perc, to!double(multi.peek().msecs) / count);
      }
      else {
	writeLog!(vl, logRankFormat)("Timer %16s was run %6d times. Total runtime %8dms, average runtime %8.0fms.", "'"~name~"'", count, multi.peek().msecs, to!double(multi.peek().msecs) / count);
      }
    }
  }

  /**
     Start the $(D MultiStopWatch) and write the current status to stdout, depending on the verbosity level and which processes are allowed to write.

     Params:
       vl = verbosity level to write at
       logRankFormat = which processes should write
  */
  void start(VL vl = VL.Debug, LRF logRankFormat = LRF.None)() {
    single.reset();
    single.start();
    multi.start();
    count++;
    writeLog!(vl, logRankFormat)("Timer '%s' started run %d.", name, count);
  }

  /**
     Stop the $(D MultiStopWatch) and write the current status to stdout, depending on the verbosity level and which processes are allowed to write.

     Params:
       vl = verbosity level to write at
       logRankFormat = which processes should write
  */
  void stop(VL vl = VL.Debug, LRF logRankFormat = LRF.None)() {
    single.stop();
    multi.stop();
    writeLog!(vl, logRankFormat)("Timer '%s' finished run %d in %dms. Total runtime %dms.", name, count, single.peek().msecs, multi.peek().msecs);
  }
}
/// Ditto
alias MSW = MultiStopWatch;

void showFinalAllTimers(VL vl, LRF logRankFormat)() {
  import std.algorithm, std.array;
  import std.conv: to;
  import std.string: format;
  assert( ("main" in timersAA) !is null );
  auto untrackedTime = timersAA["main"].multi.peek().msecs;

  import std.stdio;
  import dlbc.io.io;

  string ioBuffer;

  foreach(t; timersAA.keys
	  .map!((a) => tuple(timersAA[a].multi.peek().msecs, a))
	  .array
	  .sort!((a,b) => a[0] > b[0]) // descending order
	  ) {
    timersAA[t[1]].showFinal!(vl, logRankFormat)();
    if ( enableIO ) {
      ioBuffer ~= format("%s %d %d\n", timersAA[t[1]].name, timersAA[t[1]].count, timersAA[t[1]].peekMulti().msecs);
    }
    if ( t[1] != "main" ) {
      untrackedTime -= timersAA[t[1]].multi.peek().msecs;
    }
  }
  double perc = 100.0 * untrackedTime / to!double(timersAA["main"].peekMulti().msecs);
  writeLog!(vl, logRankFormat)("%58s %8dms (%6.2f%%)", "Untracked runtime", untrackedTime, perc);

  if ( dlbc.timers.enableIO && dlbc.io.io.enableIO ) {
    auto fileName = makeFilenameOutput!(FileFormat.Ascii)(fileNamePrefix, 0);
    auto f = File(fileName, "w"); // open for writing
    f.writeln("#? timer n t");
    f.write(ioBuffer);
  }
}

