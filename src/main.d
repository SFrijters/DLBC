import dlbc.fields.field;
import dlbc.fields.init;
import dlbc.fields.parallel;
import dlbc.getopt;
import dlbc.io.io;
import dlbc.io.hdf5;
import dlbc.lattice;
import dlbc.lb.lb;
import dlbc.logging;
import dlbc.parallel;
import dlbc.parameters;
import dlbc.random;
import dlbc.timers;
import dlbc.versions;

int main(string[] args ) {
  version(unittest) {
    globalVerbosityLevel = VL.Debug;
  }

  // Any output before startMpi() has been called will be very spammy, so better avoid it.
  startMpi(args);

  writeLogRN(makeHeaderString("Starting DLBC on %d CPUs.", M.size));

  // Process the CLI parameters.
  processCLI(args);

  // Show build-related information.
  showCompilerInfo!(VL.Information, LRF.Root);
  showRevisionInfo!(VL.Information, LRF.Root);

  startHDF5();

  // Start Main timer.
  Timers.main = MultiStopWatch("Main");
  Timers.io = MultiStopWatch("IO");
  Timers.main.start!(VL.Debug, LRF.None);

  if (M.isRoot) {
    readParameterSetFromCliFiles();
  }
  bcastParameters();
  showParameters!(VL.Information, LRF.Root);

  // Show name and id of the current simulation.
  broadcastSimulationId();

  checkPaths();

  // Set secondary values based on parameters.
  processParameters();

  // Make cartesian grid now that we have values ncx, ncy, ncz everywhere.
  reorderMpi();

  // Init random number generator.
  initRNG();

  // Try and create the local lattice structure.
  auto L = new Lattice!(3)(M);

  L.red.initRandom();
  L.red.exchangeHalo();
  L.red.dumpField("red");

  L.mask.initWallsX();
  L.mask.exchangeHalo();
  L.mask.dumpField("mask");

  Timers.adv = MultiStopWatch("Advection");
  Timers.coll = MultiStopWatch("Collision");

  for ( uint t = 1; t <= timesteps; ++t ) {
    writeLogRN("Starting timestep %d", t);
    L.red.exchangeHalo();
    L.red.advectField!d3q19(L.mask, L.advection);
    L.red.collideField!d3q19(L.mask);
    writeLogRI("Global mass = %f", L.red.globalMass(L.mask));
    writeLogRI("Global momentum = %s", L.red.globalMomentum!(d3q19)(L.mask));

    if ( t % 100 == 0 ) {
      L.red.densityField(L.mask, L.density);
      L.density.dumpField("red", t);
      //L.red.velocityField!d3q19(L.mask);
    }
  }

  Timers.main.stop();

  Timers.io.showFinal!(VL.Information, LRF.Root);
  Timers.adv.showFinal!(VL.Information, LRF.Root);
  Timers.coll.showFinal!(VL.Information, LRF.Root);
  Timers.main.showFinal!(VL.Information, LRF.Root);

  endHDF5();
  endMpi();

  writeLogRN(makeHeaderString("Finished DLBC run."));

  return 0;
}

