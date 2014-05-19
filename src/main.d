import dlbc.connectivity;
import dlbc.fields.field;
import dlbc.fields.init;
import dlbc.getopt;
import dlbc.io.io;
import dlbc.io.hdf5;
import dlbc.lattice;
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
  T.main = MultiStopWatch("Main");
  T.io = MultiStopWatch("IO");
  T.main.start!(VL.Debug, LRF.None);

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

  L.index.initRank();
  L.exchangeHalo();
  L.index.dumpField("index");


  // L.index.show!(VL.Debug, LRF.Root);
  // L.index.exchangeHalo();
  // L.index.show!(VL.Debug, LRF.Root);

  // L.blue.exchangeHalo(1);
  // L.blue.show!(VL.Debug, LRF.Root);
  // L.blue.exchangeHalo();
  // L.blue.show!(VL.Debug, LRF.Root);

  // L.red.exchangeHalo();
  // L.blue.exchangeHalo();

  // L.red.show!(VL.Debug, LRF.Root);
  // L.blue.show!(VL.Debug, LRF.Root);

  // foreach( x, y, z, ref el; L.index) {
  //   writeLogRD("%d %d %d %d", el, x, y, z);
  // }

  // foreach( x, y, z, ref el; L.index.arr) {
  //   writeLogRD("%d %d %d %d", el, x, y, z);
  // }

  // foreach(x, y, z, ref el; L.red.arr) { // using opApply
  //   writeLogRD("%d %d %d %s", x, y, z, el);
  //   el = M.rank;
  // }

  // foreach(x, y, z, ref el; L.red) {
  //   writeLogD("%d %d %d %s", x, y, z, el);
  // }

  // foreach(x, y, z, v, ref el; L.red.arr) {
  //   // Loops over physical sites of scalar field only.
  //   // assert(is(typeof(el) == double[19]) );
  //   el = x*1000+y*10+z;
  //   // writeLogRD("%d %d %d %s", x, y, z, el);
  // }
  // L.red.show!(VL.Debug, LRF.Root);
  // L.red.exchangeHalo();
  // // L.red.show!(VL.Debug, LRF.Root);
  // writeLogRD(L.red.arr[0..$,0..$,2,1].toString);
  // auto buffer = L.red.arr[0..$-1,0..$,0..$, 1];
  // writeLogRD(buffer.toString);
  // L.red.arr[1..$,0..$,0..$,1] = buffer;
  // // L.red.show!(VL.Debug, LRF.Root);

  // // writeLogRD(L.red.arr[0..$,0..$,0..$,1].toString);
  // writeLogRD(L.red.arr[0..$,0..$,2,1].toString);

  // foreach( z, y, x, ref el; L.red.arr) {
  //   writeLogRD("%s %d %d %d", el, z, y, x);
  // }

  // L.index.show!(VL.Debug, LRF.Any);
  // L.blue.show!(VL.Debug, LRF.Any);

  // L.red.initConst(0.01);
  L.red.initRandom();
  L.red.exchangeHalo();
  L.red.dumpField("red");
  // L.red.exchangeHalo();
  // L.red.show!(VL.Debug, LRF.Root);

  // writeLogI(L.red.densityField().toString());

  T.adv = MultiStopWatch("Advection");
  T.coll = MultiStopWatch("Collision");

  auto d3q19 = new Connectivity!(3,19);

  for ( uint t = 1; t <= 0; ++t ) {
    writeLogRN("Starting timestep %d", t);
    // writeLogRI("Density = %f", L.red.localMass());
    writeLogRI("Mass before advection = %f", L.red.globalMass());
    // writeLogI("Density = %f", L.red.localMass());
    L.red.exchangeHalo();
    T.adv.start();
    L.red.advectField(L.temp, d3q19);
    T.adv.stop();
    writeLogRI("Mass after advection = %f", L.red.globalMass());
    // writeLogI("Density = %f", L.red.localMass());
    // L.red.show!(VL.Debug, LRF.Root);
    T.coll.start();
    L.red.collideField(d3q19);
    T.coll.stop();
    writeLogRI("Global momentum = %s", L.red.globalMomentum(d3q19));
    // L.red.show!(VL.Debug, LRF.Root);
  }
  // L.red.show!(VL.Information, LRF.Root);

  // writeLogRD("%f", [1.0, 3.0, 0.5].dot([0.0,3.0,2.0]));

  T.io.showFinal!(VL.Information, LRF.Ordered);
  T.adv.showFinal!(VL.Information, LRF.Ordered);
  T.coll.showFinal!(VL.Information, LRF.Ordered);
  T.main.stop();
  T.main.showFinal!(VL.Information, LRF.Ordered);

  // writeLogI(L.red.densityField().toString());

  endHDF5();
  endMpi();

  writeLogRN(makeHeaderString("Finished DLBC run."));

  return 0;
}

