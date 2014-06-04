module tests.runnable.laplace;

version(unittest) {

import tests.test;

int runTest() {
  writeLogRN(makeHeaderString("Running test '%s'", __MODULE__));

  immutable string parameterFile = runnableTestPath ~ "laplace-parameters.txt";
  dlbc.parameters.parameterFileNames = [ parameterFile ];
  
  initParameters();
  initCommon();

  double[] radii = [ 5.0, 6.0, 7.0, 8.0, 9.0, 10.0 ];

  foreach(immutable r; radii) {
    dlbc.lb.init.sphereRadius.setParameter(r);
    writeLogRN("Performing simulation with dlbc.lb.init.sphereRadius = %f.", dlbc.lb.init.sphereRadius);
    // showParameters!(VL.Information, LRF.Root);

    auto L = Lattice!(gconn)(M);
    timestep = 0;
    initLattice(L);
    runTimeloop(L);
  }

  writeLogRN(makeHeaderString("Finished test '%s'", __MODULE__));
  return 0;
}

}

