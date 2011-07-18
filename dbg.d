import std.stdio;

import parameters;
import stdio;

void dbgShowMixins() {

  debug(showMixins) {
    globalVerbosityLevel = VL.Debug;
    writeLogRD("--- START makeParameterSetMembers() mixin ---\n");
    writeln(makeParameterSetMembers());
    writeLogRD("--- END   makeParameterSetMembers() mixin ---\n");

    writeLogRD("--- START makeParameterSetShow() mixin ---\n");
    writeln(makeParameterSetShow());
    writeLogRD("--- END   makeParameterSetShow() mixin ---\n");

    writeLogRD("--- START makeParameterSetMpiType() mixin ---\n");
    writeln(makeParameterSetMpiType());
    writeLogRD("--- END   makeParameterSetMpiType() mixin ---\n");

    writeLogRD("--- START makeParameterCase() mixin ---\n");
    writeln(makeParameterCase());
    writeLogRD("--- END   makeParameterCase() mixin ---\n");
  }

}
