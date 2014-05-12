import dlbc.getopt;
import dlbc.hdf5;
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

  debug(showMixins) { dbgShowMixins(); }

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

  double[19] test = M.rank;

  L.red[] = test;
  // L.blue[] = M.rank;
  // L.index[] = M.rank;

  L.red.initRandom();
  L.blue.initRandom();

  L.index.exchangeHalo!(1);
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

  foreach(x, y, z, ref el; L.red) {
    writeLogD("%d %d %d %s", x, y, z, el);
  }

  // foreach(x, y, z, ref el; L.red) {
  //   // Loops over physical sites of scalar field only.
  //   assert(is(typeof(el) == double[19]) );
  //   writeLogRD("%s %d %d %d", el, x, y, z);
  // }

  // foreach( z, y, x, ref el; L.red.arr) {
  //   writeLogRD("%s %d %d %d", el, z, y, x);
  // }

  // L.index.show!(VL.Debug, LRF.Root);


  // L.blue.show!(VL.Debug, LRF.Root);

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

  T.main.stop!(VL.Information, LRF.Ordered);

  // endHDF5();
  endMpi();

  writeLogRN(makeHeaderString("Finished DLBC run."));

  return 0;
}

