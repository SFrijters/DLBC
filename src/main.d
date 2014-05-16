import dlbc.connectivity;
import dlbc.getopt;
import dlbc.hdf5;
import dlbc.fields.field;
import dlbc.fields.init;
import dlbc.io;
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

  // Process the CLI parameters
  processCLI(args);

  // Show build-related information
  showCompilerInfo!(VL.Information, LRF.Root);
  showRevisionInfo!(VL.Information, LRF.Root);

  // startHDF5();

  // Start Main timer
  T.main = MultiStopWatch("Main");
  T.main.start!(VL.Debug, LRF.None);

  if (M.isRoot) {
    readParameterSetFromCliFiles();
  }
  bcastParameters();
  showParameters!(VL.Information, LRF.Root);

  // Set secondary values based on parameters
  processParameters();

  // Make cartesian grid now that we have values ncx, ncy, ncz everywhere
  reorderMpi();
  M.show!(VL.Debug, LRF.Ordered);

  // Init random number generator.
  initRNG();

  // Try and create the local lattice structure
  auto L = new Lattice!(3)(M);

  L.exchangeHalo();

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

  // writeLog(VL.Information, LRF.None, "This is another None log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Root, "This is another Root log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Any, "This is another Any log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Ordered, "This is another Ordered log test from rank %d.\n",M.rank);

  // import dlbc.revision;
  // // auto mods = [ dlbc.revision ];
  // // foreach(m ; mods) {
  // foreach(e ; __traits(derivedMembers, dlbc.lattice)) {
  //   writeLogRD(e);
  //   pragma(msg, e);
  // //   mixin(`
  // //     foreach( t; __traits(getAttributes, dlbc.lattice.`~e~`)) {
  // //   pragma(msg, t); writeLogRD(t);
  // // }`);
  // //   mixin(`
  // //     foreach( t; __traits(parent, dlbc.lattice.`~e~`)) {
  // //   pragma(msg, t); writeLogRD(t);
  // // }`);
  // }


  //   //  }
  // }


  // Check advection - make this into a unittest later.


  // Check velocity - make this into a unittest later.
  // double[19] pop = [ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  // 		     0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  // auto den = density(pop);
  // auto vel = velocity(pop, d3q19);
  // writeLogRD("%s %s %s", pop, den ,vel);
  // auto eqPop = eqDist(pop, d3q19);
  // writeLogRD("%s %s %s", eqPop, density(eqPop), velocity(eqPop, d3q19));

  // L.red.initConst(0.01);
  L.red.initRandom();
  // L.red.exchangeHalo();
  // L.red.show!(VL.Debug, LRF.Root);

  // writeLogI(L.red.densityField().toString());

  T.adv = MultiStopWatch("Advection");
  T.coll = MultiStopWatch("Collision");

  auto d3q19 = new Connectivity!(3,19);

  for ( uint t = 1; t <= 100; ++t ) {
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

  T.adv.showFinal!(VL.Information, LRF.Ordered);
  T.coll.showFinal!(VL.Information, LRF.Ordered);
  T.main.stop();
  T.main.showFinal!(VL.Information, LRF.Ordered);

  // writeLogI(L.red.densityField().toString());

  // endHDF5();
  endMpi();

  writeLogRN(makeHeaderString("Finished DLBC run."));

  return 0;
}

