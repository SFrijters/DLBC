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

/// Test Doxygen
int main( string[] args ) {

  startMpi();

  // if (M.rank > 0) Thread.sleep(10_000_000);

  // writelog("Hello World from process %d of %d.", M.rank, M.size );
  // writelog();

  // if (M.rank > 0) Thread.sleep(dur!("seconds")(1));

  // MPI_Barrier( MPI_COMM_WORLD );

  // debug(2) {
  //   if (M.rank == 0) {
  //     writelog( "Rank 0 reporting.");
  //   }
  // }

  if (M.rank == 0) {
    readParameterSetFromFile("test.txt");
    listParameterValues();
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

 
  // for(int i=0;i<nx;i++)
  //   for(int j=0;j<ny;j++)
  //     for(int k=0;k<nz;k++) {
  // 	writelog("L.R(%d,%d,%d) = %f",i,j,k,L.R[k][j][i]);
  // 	writelog("L.B(%d,%d,%d) = %f",i,j,k,L.B[k][j][i]);
  //     }

  assert(L.R[2][1][0] == 3,  "Lattice R content test failed.");
  assert(L.B[3][2][0] == -1, "Lattice B content test failed.");

}

