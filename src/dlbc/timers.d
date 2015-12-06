// Written in the D programming language.

/**
   Timers for performance measurement.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.timers;

import std.datetime;

import std.array;
import dlbc.logging;

/**
   Enable writing the timing data to disk in raw ascii format.
*/
@("param") bool enableIO = false;

private immutable string mainTimerName = "main";
private immutable string fileNamePrefix = "timers";

private uint startTimestep;

private MSW[string] timersAA;
private string[] timerStack;

/**
   Start a timer. The full name of the timer depends on the timers currently on the stack.

   Params:
     name = local name of the timer
*/
void startTimer(VL vl = VL.Debug, LRF logRankFormat = LRF.None)(in string name) {
  if ( ! timerStack.empty ) {
    immutable string parentName = timerNameFromStack();
    assert( (parentName in timersAA) !is null );
    timersAA[parentName].pause!(vl, logRankFormat)();
  }

  timerStack ~= name;
  immutable string fullName = timerNameFromStack();
  if ( (fullName in timersAA) is null ) {
    timersAA[fullName] = MSW(fullName);
  }
  timersAA[fullName].start!(vl, logRankFormat)();
}

/**
   Start the main timer. This should normally be the first timer that is started and the
   last one to be stopped.
*/
void startMainTimer(VL vl = VL.Debug, LRF logRankFormat = LRF.None)() {
  startTimer!(vl, logRankFormat)(mainTimerName);
}

/**
   Stop a timer. The full name of the timer depends on the timers currently on the stack.

   Params:
     name = local name of the timer
*/
void stopTimer(VL vl = VL.Debug, LRF logRankFormat = LRF.None)(in string name) {
  assert( timerStack.back == name );

  immutable string fullName = timerNameFromStack();

  assert( (fullName in timersAA) !is null );
  timersAA[fullName].stop!(vl, logRankFormat)();
  timerStack.popBack();

  if ( ! timerStack.empty ) {
    immutable string parentName = timerNameFromStack();
    assert( (parentName in timersAA) !is null );
    timersAA[parentName].resume!(vl, logRankFormat)();
  }
}

/**
   Stop the main timer. This should normally be the first timer that is started and the
   last one to be stopped.
*/
void stopMainTimer(VL vl = VL.Debug, LRF logRankFormat = LRF.None)() {
  stopTimer!(vl, logRankFormat)(mainTimerName);
}

/**
   Create the full name of the currently active timer.
*/
private string timerNameFromStack() {
  return timerStack.join(".");
}

void setTimerStartTimestep() {
  import dlbc.lb.lb: timestep;
  startTimestep = timestep;
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
     Write the current status of the $(D MultiStopWatch) to stdout, depending on the verbosity level and which processes are allowed to write.
  */
  void show(VL vl, LRF logRankFormat)() {
    writeLog!(vl, logRankFormat)("Timer '%s' measuring run %d for %dms. Total runtime %dms.", name, count, single.peek().msecs, multi.peek().msecs);
  }

  /**
     Start the $(D MultiStopWatch) and write the current status to stdout, depending on the verbosity level and which processes are allowed to write.
  */
  void start(VL vl = VL.Debug, LRF logRankFormat = LRF.None)() {
    single.reset();
    single.start();
    multi.start();
    ++count;
    writeLog!(vl, logRankFormat)("Timer '%s' started run %d.", name, count);
  }

  /**
     Stop the $(D MultiStopWatch) and write the current status to stdout, depending on the verbosity level and which processes are allowed to write.
  */
  void stop(VL vl = VL.Debug, LRF logRankFormat = LRF.None)() {
    single.stop();
    multi.stop();
    writeLog!(vl, logRankFormat)("Timer '%s' finished run %d in %dms. Total runtime %dms.", name, count, single.peek().msecs, multi.peek().msecs);
  }

  /**
     Pause the $(D MultiStopWatch) and write the current status to stdout, depending on the verbosity level and which processes are allowed to write.
  */
  void pause(VL vl = VL.Debug, LRF logRankFormat = LRF.None)() {
    single.stop();
    multi.stop();
    writeLog!(vl, logRankFormat)("Timer '%s' paused run %d.", name, count);
  }

  /**
     Resume the $(D MultiStopWatch) and write the current status to stdout, depending on the verbosity level and which processes are allowed to write.
  */
  void resume(VL vl = VL.Debug, LRF logRankFormat = LRF.None)() {
    single.start();
    multi.start();
    writeLog!(vl, logRankFormat)("Timer '%s' paused run %d.", name, count);
  }

}
/// Ditto
alias MSW = MultiStopWatch;

/**
   Write final timer information to stdout, and write to file if requested through $(D enableIO).
*/
void showFinalAllTimers(VL vl, LRF logRankFormat)() {
  import std.algorithm, std.array;
  import std.conv: to;
  import std.string: format;
  import std.typecons: tuple;
  assert( (mainTimerName in timersAA) !is null );

  import std.stdio;
  import dlbc.io.io;

  string ioBuffer;

  double totalTime = 0;
  size_t maxWidth = 0;
  foreach(t; timersAA.keys) {
    totalTime += timersAA[t].multi.peek().msecs;
    maxWidth = max(maxWidth, t.length);
  }

  string formatStr = format("Timer %%%ds was run %%6d times. Total runtime %%8dms (%%6.2f%%%%), average runtime %%6.2ems.", maxWidth + 2); // +2 for the two single quotes

  foreach(t; timersAA.keys
	  .map!((a) => tuple(timersAA[a].multi.peek().msecs, a))
	  .array
	  .sort!((a,b) => a[0] > b[0]) // descending order in duration
	  .map!((a) => (a[1]))
	  ) {

    immutable time  = timersAA[t].multi.peek().msecs;
    immutable count = timersAA[t].count;
    immutable name  = timersAA[t].name;
    immutable perc  = 100.0 * time / totalTime;

    if ( count > 0 ) {
      writeLog!(vl, logRankFormat, false)(formatStr, "'"~name~"'", count, time, perc, to!double(time) / count);
    }

    if ( enableIO ) {
      ioBuffer ~= format("%s %d %d\n", name, count, time);
    }
  }

  import dlbc.lattice: gn;
  import dlbc.parallel: M;
  int nls = 1;
  foreach(n; gn) {
    nls *= n;
  }
  import dlbc.lb.lb: timestep;
  immutable timesteps = timestep - startTimestep;
  writeLog!(vl, logRankFormat)("\nUpdated %d lattice sites for %d timesteps in %e seconds: %e LUPS (%e LUPS/rank).", nls, timesteps, 0.001 * totalTime, 1000.0 * nls * timesteps / totalTime, 1000.0 * nls * timesteps / ( totalTime * M.size ) );

  if ( dlbc.timers.enableIO && dlbc.io.io.enableIO ) {
    auto fileName = makeFilenameOutput!(FileFormat.Ascii)(fileNamePrefix, 0);
    auto f = File(fileName, "w"); // open for writing
    f.writeln("#? timer n t");
    f.write(ioBuffer);
  }
}

