import std.stdio;
import std.algorithm;
import std.datetime;
import std.conv;
import std.string;
import core.thread;

import dbg: dbgShowMixins;
import mpi;
import parallel;
import parameters;
import stdio;


struct Lattice {
  double[][][] R;
  double[][][] B;
  
  this (ulong nx, ulong ny, ulong nz) {
     R = new double[][][nz];
     foreach (ref Ry; R) {
       Ry = new double[][ny];
       foreach (ref Rx; Ry) {
	 Rx = new double[nx];
       }
     }

     B = new double[][][nz];
     foreach (ref By; B) {
       By = new double[][ny];
       foreach (ref Bx; By) {
	 Bx = new double[nx];
       }
     }
  }

}

Lattice L;


void divideLattice() {
  ulong nx, ny, nz;
  
  if (P.nx % M.ncx != 0 || P.ny % M.ncy != 0 || P.nz % M.ncz != 0) {
    writeLogF("Cannot divide lattice evenly...");
    throw new Exception("Lattice division exception");
  }

  nx = P.nx / M.ncx;
  ny = P.ny / M.ncy;
  nz = P.nz / M.ncz;

  //writelogI("Initializing %d x %d x %d lattice...",nx,ny,nz);

  L = Lattice(nx,ny,nz);

}

/// Test Doxygen
int main( string[] args ) {
  debug {
    globalVerbosityLevel = VL.Debug;
  }

  // Any output before startMpi() has been called will be very spammy, so better avoid it.
  startMpi();
  
  writeLogRN("\nStarted DLBC on %d CPUs.\n", M.size);

  // Process the CLI parameters
  processCLI(args);

  dbgShowMixins();

  // Create an MPI type for the ParameterSet struct
  setupParameterSetMpiType();

  // No cartesian grid yet, but rank 0 can read stuff
  if (M.rank == M.root) {
    readParameterSetFromFile(parameterFileName);
  }

  // Get the parameters to all CPUs
  distributeParameterSet();

  // Set secondary values based on parameters
  processParameters();

  // Make cartesian grid now that we have values ncx, ncy, ncz everywhere
  reorderMpi();

  // Try and split the lattice
  divideLattice();

  // if (M.rank == M.root) {
  //   M.show();
  //   P.show();
  // }

  owriteLogD("This is a test from rank %d.",M.rank);
  writeLogD("This is a test from rank %d.",M.rank);

  endMpi();

  writeLogRN("\nFinished DLBC run.\n");

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

