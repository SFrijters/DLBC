import getopt;
import lattice;
import logging;
import parallel;
import parameters;
import timers;
import versions;

int main(string[] args ) {

  // Any output before startMpi() has been called will be very spammy, so better avoid it.
  startMpi(args);

  writeLogRN(makeHeaderString("Starting DLBC on %d CPUs."), M.size);

  // Show build-related information
  showCompilerInfo!(VL.Information, LRF.Root);
  showRevisionInfo!(VL.Information, LRF.Root);

  // Start Main timer
  T.main = MultiStopWatch("Main");
  T.main.start!(VL.Debug, LRF.None);

  // Process the CLI parameters
  processCLI(args);

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

  // Try and create the local lattice structure
  L = Lattice(M, P);

  L.red[] = M.rank;

  L.red.haloExchange();
  L.blue.haloExchange();

  L.red.show!(VL.Debug, LRF.Root);

  // writeLog(VL.Information, LRF.None, "This is another None log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Root, "This is another Root log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Any, "This is another Any log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Ordered, "This is another Ordered log test from rank %d.\n",M.rank);

  T.main.stop!(VL.Information, LRF.Ordered);

  endMpi();

  writeLogRN(makeHeaderString("Finished DLBC run."));

  return 0;
}

