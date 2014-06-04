module tests.test;

import dlbc.logging;

@("param") RunnableTests[] testsToRun;

enum RunnableTests {
  All,
  Laplace,
}

bool isTesting() {
  version(unittest) {
    return ( testsToRun.length > 0 );
  }
  else {
    if ( testsToRun.length > 0 ) {
      writeLogRF("Runnable tests are only available when the code is compiled with -unittest.");
    }
    return false;
  }
}

version(unittest) {

  public import main;

  mixin(createTestImportMixin());

  immutable string runnableTestPath = "src/tests/runnable/";

  void runTests() {
    import std.algorithm: canFind;
    if ( testsToRun.canFind(RunnableTests.All) ) {
      runAllTests();
    }
    else {
      foreach(immutable t; testsToRun) {
        final switch(t) {
          mixin(createTestCaseMixin());
        }
      }
    }
  }

  void runAllTests() {
    import std.string: toLower;
    writeLogRN("Performing all runnable tests...");
    foreach (m; __traits(allMembers, RunnableTests)) {
      static if ( m != "All") {
        mixin("tests.runnable."~m.toLower()~".runTest();");
      }
    }
  }

  private string createTestCaseMixin() {
    import std.string: toLower;
    string mixinString;
    foreach (m; __traits(allMembers, RunnableTests)) {
      static if ( m != "All") {
        mixinString ~= "case RunnableTests."~m~":\n";
        mixinString ~= "  tests.runnable."~m.toLower()~".runTest();\n";
        mixinString ~= "  break;\n";
      }
      else {
        mixinString ~= "case RunnableTests."~m~":\n  break;";
      }
    }
    return mixinString;
  }

  private string createTestImportMixin() {
    import std.string: toLower;
    string mixinString;
    foreach (m; __traits(allMembers, RunnableTests)) {
      static if ( m != "All") {
        mixinString ~= "import tests.runnable." ~ m.toLower() ~ ";\n";
      }
    }
    return mixinString;
  }

}

