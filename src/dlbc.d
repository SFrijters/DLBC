import lattice;
import logging;
import parallel;
import parameters;
import revision;
import timers;

int main( string[] args ) {

  // Any output before startMpi() has been called will be very spammy, so better avoid it.
  startMpi();

  writeLogRN(makeHeaderString("Starting DLBC on %d CPUs."), M.size);

  T.main = MultiStopWatch("Main");
  T.main.start(LRF.None);

  // Process the CLI parameters
  processCLI(args);

  debug(showMixins) { dbgShowMixins(); }

  // Create an MPI type for the ParameterSet struct
  setupParameterSetMpiType();

  // No cartesian grid yet, but the root can read stuff
  if (M.rank == M.root) {
    readParameterSetFromCliFiles();
  }

  // Get the parameters to all CPUs
  distributeParameterSet();

  // Set secondary values based on parameters
  processParameters();

  if (revisionChanges.length == 0) {
    writeLogRI("Executable built from revision %s .", revisionNumber );
  }
  else {
    writeLogRI("Executable built from revision %s (with local changes).", revisionNumber );
    writeLogRD("  Changes from HEAD: %s.\n", revisionChanges );
  }
  
  if (M.rank == M.root) {
    P.show();
  }

  // Make cartesian grid now that we have values ncx, ncy, ncz everywhere
  reorderMpi();

  // Try and split the lattice
  divideLattice();

  owriteLogD("This is a test from rank %d.",M.rank);
  writeLogD("This is a test from rank %d.",M.rank);

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

