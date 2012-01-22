import logging;
import parameters;
import parallel;

Lattice L;

/// Create lattice L for every CPU, according to cartesian decomposition and halo size
void createLocalLattice() {
  ulong nx, ny, nz;
  
  // Check if we can reconcile global lattice size with CPU grid
  if (P.nx % M.ncx != 0 || P.ny % M.ncy != 0 || P.nz % M.ncz != 0) {
    writeLogRF("Cannot divide lattice evenly.");
    throw new Exception("Lattice division exception");
  }

  // Calculate local lattice size
  nx = P.nx / M.ncx;
  ny = P.ny / M.ncy;
  nz = P.nz / M.ncz;

  // Check for bogus halo
  int haloSize = P.haloSize;
  if (haloSize < 1) {
    writeLogRF("Halo size < 1 not allowed.");
    throw new Exception("Halo size exception");
  }

  writeLogRI("Initializing %d x %d x %d local lattice with halo of thickness %d.", nx, ny, nz, P.haloSize);

  // Create lattice
  L = Lattice(nx, ny, nz, P.haloSize);

}

struct Lattice {
  double[][][] R;

  ulong nx, ny, nz;
  ulong nxH, nyH, nzH;
  ulong haloSize;
  
  this (immutable ulong nx, immutable ulong ny, immutable ulong nz, immutable ulong haloSize) {

    this.nx  = nx;
    this.ny  = ny;
    this.nz  = nz;
    this.haloSize   = haloSize;
    this.nxH = haloSize + nx + haloSize;
    this.nyH = haloSize + ny + haloSize;
    this.nzH = haloSize + nz + haloSize;
    
    R = new double[][][](nzH, nyH, nxH);

  }

  void fillWithRank() {
    for(int i=0;i<L.nxH;i++) {
      for(int j=0;j<L.nyH;j++) {
	for(int k=0;k<L.nzH;k++) {
	  R[k][j][i] = M.rank;
	}
      }
    }
  }

}

