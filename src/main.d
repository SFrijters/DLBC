import dlbc.getopt;
import dlbc.hdf5;
import dlbc.field.init;
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

  L.haloExchange();
  
  L.red[] = M.rank;
  L.blue[] = M.rank;

  L.red.haloExchange();
  L.blue.haloExchange();

  L.red.show!(VL.Debug, LRF.Root);

  L.blue.show!(VL.Debug, LRF.Root);

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

