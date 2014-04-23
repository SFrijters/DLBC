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

  writeLogRN(makeHeaderString("Starting DLBC on %d CPUs."), M.size);

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

  // Create an MPI type for the ParameterSet struct
  setupParameterSetMpiType();
  setupParameterSetDefaultMpiType();

  // No cartesian grid yet, but the root can read stuff
  if (M.isRoot) {
    readParameterSetFromCliFiles();
  }

  // Get the parameters to all CPUs
  distributeParameterSet();

  // Set secondary values based on parameters
  processParameters();

  P.show!(VL.Information, LRF.Root);

  // Make cartesian grid now that we have values ncx, ncy, ncz everywhere
  reorderMpi();
  M.show!(VL.Debug, LRF.Ordered);

  // Init random number generator.
  initRNG();

  // Try and create the local lattice structure
  auto L = new Lattice!(3)(M, P);

  L.exchangeHalo();

  L.red[] = M.rank;
  L.blue[] = M.rank;
  L.index[] = M.rank;

  // L.red.initRandom();
  // L.blue.initRandom();

  L.index.exchangeHalo(1);
  L.index.show!(VL.Debug, LRF.Root);
  L.index.exchangeHalo();
  L.index.show!(VL.Debug, LRF.Root);

  L.blue.exchangeHalo(1);
  L.blue.show!(VL.Debug, LRF.Root);
  L.blue.exchangeHalo();
  L.blue.show!(VL.Debug, LRF.Root);


  // L.red.exchangeHalo();
  // L.blue.exchangeHalo();

  // L.red.show!(VL.Debug, LRF.Root);
  // L.blue.show!(VL.Debug, LRF.Root);

  // foreach(v, z, y, x, ref el; L.red) { // using opApply
  //   el = z * 100 + y * 10 + x;
  // }


  // foreach(z, y, x, ref el; L.index) {
  //   writeLogRD("%d %d %d %d", el, z, y, x);
  // }

  // foreach(z, y, x, ref el; L.index.arr) {
  //   writeLogRD("%d %d %d %d", el, z, y, x);
  // }

  // L.index.show!(VL.Debug, LRF.Root);


  // L.blue.show!(VL.Debug, LRF.Root);

  // writeLog(VL.Information, LRF.None, "This is another None log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Root, "This is another Root log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Any, "This is another Any log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Ordered, "This is another Ordered log test from rank %d.\n",M.rank);

  T.main.stop!(VL.Information, LRF.Ordered);

  // endHDF5();
  endMpi();

  writeLogRN(makeHeaderString("Finished DLBC run."));

  return 0;
}

