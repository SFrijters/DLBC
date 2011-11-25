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

  void show() {
    writeLogI(makeStopString());
  }

  void showR() {
    writeLogRI(makeStopString());
  }

  void oshow() {
    owriteLogI(makeStopString());
  }

  void start(LRF logRankFormat ) {
    single.reset();
    single.start();
    multi.start();
    count++;

    final switch(logRankFormat) {
      case LRF.None:    break;
      case LRF.Root:    writeLogRI(makeStartString()); break;
      case LRF.Any:     writeLogI(makeStartString()); break;
      case LRF.Ordered: owriteLogI(makeStartString()); break;
    }
  }

  void stop(LRF logRankFormat ) {
    single.stop();
    multi.stop();

    final switch(logRankFormat) {
      case LRF.None:    break;
      case LRF.Root:    showR(); break;
      case LRF.Any:     show(); break;
      case LRF.Ordered: oshow(); break;
    }
  }

  private string makeStopString() {
    string reportString = format("Timer '%s' finished run %d in %dms. Total runtime %dms.", name, count, single.peek().msecs, multi.peek().msecs);
    return reportString;
  }

  private string makeStartString() {
    string reportString = format("Timer '%s' started run %d.", name, count);
    return reportString;
  }

}

