import std.datetime;
import std.string;

import logging;
  
alias Timers T;
struct Timers {
  static MSW main;
}

alias MultiStopWatch MSW;
struct MultiStopWatch {
  private StopWatch single, multi;
  int count;
  string name;

  this (string n) {
    name = n;
  }

  auto peekSingle() {
    return single.peek();
  }

  auto peekMulti() {
    return multi.peek();
  }

  void show(VL vl, LRF logRankFormat)() {
    writeLog(vl, logRankFormat, "Timer '%s' measuring run %d for %dms. Total runtime %dms.", name, count, single.peek().msecs, multi.peek().msecs);
  }

  void start(VL vl, LRF logRankFormat)() {
    single.reset();
    single.start();
    multi.start();
    count++;
    writeLog(vl, logRankFormat, "Timer '%s' started run %d.", name, count);
  }

  void stop(VL vl, LRF logRankFormat)() {
    single.stop();
    multi.stop();
    writeLog(vl, logRankFormat, "Timer '%s' finished run %d in %dms. Total runtime %dms.", name, count, single.peek().msecs, multi.peek().msecs);
  }

}

