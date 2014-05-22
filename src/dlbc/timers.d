// Written in the D programming language.

/**
   Timers for performance measurement.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.timers;

import std.datetime;
import std.string;

import dlbc.logging;

/**
   Container for multiple timers.
*/
struct Timers {
  static MSW main;
  static MSW adv;
  static MSW coll;
  static MSW io;
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
    writeLog!(vl, logRankFormat)("Timer '%s' was run %d times. Total runtime %dms, average runtime %fms.", name, count, multi.peek().msecs, to!double(multi.peek().msecs) / count);
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
alias MultiStopWatch MSW;

private string createInitAllTimersMixin() {
  string mixinString;
  foreach(e ; __traits(allMembers, Timers) ) {
    mixinString ~= `  Timers.`~e~` = MultiStopWatch("`~e~`");`;
  }
  return mixinString;
}

void initAllTimers() {
  mixin(createInitAllTimersMixin());
}

private string createShowFinalAllTimersMixin() {
  string mixinString;
  foreach(e ; __traits(allMembers, Timers) ) {
    mixinString ~= `  Timers.`~e~`.showFinal!(vl, logRankFormat);`;
  }
  return mixinString;
}

void showFinalAllTimers(VL vl, LRF logRankFormat)() {
  mixin(createShowFinalAllTimersMixin());
}

