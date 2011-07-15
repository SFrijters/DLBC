import std.stdio;
import std.algorithm;
import std.datetime;
import std.conv;
import std.string;
import core.thread;

import mpi;
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
    writelog("Cannot divide lattice evenly...");
    throw new Exception("Lattice division exception");
  }

  nx = P.nx / M.ncx;
  ny = P.ny / M.ncy;
  nz = P.nz / M.ncz;

  //writelog("Initializing %d x %d x %d lattice...",nx,ny,nz);

  L = Lattice(nx,ny,nz);

}

/// Test Doxygen
int main( string[] args ) {

  // Any output before startMpi() has been called will be very spammy, so better avoid it.
  startMpi();
  
  if (M.rank == 0) {
    debug(showMixins) {
      writeln("--- START makeParameterSetMembers() mixin ---\n");
      writeln(makeParameterSetMembers());
      writeln("--- END   makeParameterSetMembers() mixin ---\n");

      writeln("--- START makeParameterSetShow() mixin ---\n");
      writeln(makeParameterSetShow());
      writeln("--- END   makeParameterSetShow() mixin ---\n");

      writeln("--- START makeParameterSetMpiType() mixin ---\n");
      writeln(makeParameterSetMpiType());
      writeln("--- END   makeParameterSetMpiType() mixin ---\n");

      writeln("--- START makeParameterCase() mixin ---\n");
      writeln(makeParameterCase());
      writeln("--- END   makeParameterCase() mixin ---\n");
    }
  }

  setupParameterSetMpiType();

  // No cartesian grid yet, but rank 0 can read stuff
  if (M.rank == 0) {
    readParameterSetFromFile("test.txt");
  }

  // Get the parameters to all CPUs
  distributeParameterList();

  // Make cartesian grid now that we have values ncx, ncy, ncz everywhere
  reorderMpi();

  // Try and split the lattice
  divideLattice();

  if (M.rank == 0) {
    M.show();
    P.show();
  }

  endMpi();

  return 0;
}

unittest {

  Lattice L;
  static ulong nx = 2;
  static ulong ny = 3;
  static ulong nz = 4;

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

