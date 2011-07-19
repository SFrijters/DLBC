import std.stdio;
import std.algorithm;
import std.datetime;
import std.conv;
import std.string;
import core.thread;

import lattice;
import parallel;
import parameters;
import revision;
import stdio;
import timers;

/** Test Doxygen */
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
  const ulong nx = 2;
  const ulong ny = 3;
  const ulong nz = 4;

  L = Lattice(nx,ny,nz);
  for(int i=0;i<nx;i++)
    for(int j=0;j<ny;j++)
      for(int k=0;k<nz;k++) {
	L.R[k][j][i] = i+j+k;
	L.B[k][j][i] = i+j-k;
      }

  assert(L.R[2][1][0] == 3,  "Lattice R content test failed.");
  assert(L.B[3][2][0] == -1, "Lattice B content test failed.");

}

