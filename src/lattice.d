import logging;
import parameters;
import parallel;

Lattice L;

alias haloSize H;
int haloSize;


void fillLatticeWithRank() {
  for(int i=0;i<L.nxH;i++)
    for(int j=0;j<L.nyH;j++)
      for(int k=0;k<L.nzH;k++) {
	L.R[k][j][i] = M.rank;
      }
}


void divideLattice() {
  ulong nx, ny, nz;
  
  if (P.nx % M.ncx != 0 || P.ny % M.ncy != 0 || P.nz % M.ncz != 0) {
    writeLogRF("Cannot divide lattice evenly.");
    throw new Exception("Lattice division exception");
  }

  nx = P.nx / M.ncx;
  ny = P.ny / M.ncy;
  nz = P.nz / M.ncz;

  writeLogRI("Initializing %d x %d x %d local lattice with halo of thickness %d.", nx, ny, nz, H);

  L = Lattice(nx, ny, nz, H);

}

struct Lattice {
  double[][][] R;

  ulong nx, ny, nz;
  ulong nxH, nyH, nzH;
  ulong H;
  
  this (immutable ulong nx, immutable ulong ny, immutable ulong nz, immutable ulong H) {

    this.nx  = nx;
    this.ny  = ny;
    this.nz  = nz;
    this.H   = H;
    this.nxH = H + nx + H;
    this.nyH = H + ny + H;
    this.nzH = H + nz + H;
    
    R = new double[][][](nzH, nyH, nxH);

  }

}

