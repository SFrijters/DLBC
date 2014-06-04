module tests.runnable.laplace;

import dlbc.logging;

int runTest() {
  writeLogRN(makeHeaderString("Running test '%s'", __MODULE__));

  writeLogRN(makeHeaderString("Finished test '%s'", __MODULE__));
  return 0;
}

