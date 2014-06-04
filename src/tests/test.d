module tests.test;

import dlbc.logging;

@("param") RunnableTests[] testsToRun;

enum RunnableTests {
  All,
  Laplace,
}

void runTests() {
  writeLogRD("%s", testsToRun);
}

bool isTesting() {
  return ( testsToRun.length > 0 );
}

