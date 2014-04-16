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
  showCompilerInfo();
  showRevisionInfo();

  // Start Main timer
  T.main = MultiStopWatch("Main");
  T.main.start(LRF.None);

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

  P.show(LRF.Root);

  // Make cartesian grid now that we have values ncx, ncy, ncz everywhere
  reorderMpi();
  M.show(VL.Debug, LRF.Ordered);

  // Try and create the local lattice structure
  createLocalLattice();
  L.haloExchange();

  // writeLog(VL.Information, LRF.None, "This is another None log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Root, "This is another Root log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Any, "This is another Any log test from rank %d.\n",M.rank);
  // writeLog(VL.Information, LRF.Ordered, "This is another Ordered log test from rank %d.\n",M.rank);

  T.main.stop(LRF.Ordered);

  endMpi();

  writeLogRN(makeHeaderString("Finished DLBC run."));

  return 0;
}

unittest {

  Lattice L;
  immutable ulong nx = 2;
  immutable ulong ny = 3;
  immutable ulong nz = 4;
  immutable ulong H = 1;

  L = Lattice(nx,ny,nz,H);

  for(int i=0;i<L.nxH;i++)
    for(int j=0;j<L.nyH;j++)
      for(int k=0;k<L.nzH;k++) {
	L.R[k][j][i] = i+j+k;
      }

  assert(L.R[2][1][0] == 3,  "Lattice R content test failed.");

}

