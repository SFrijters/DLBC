import parameters;
import parallel;
import stdio;

public:

Lattice L;

void divideLattice() {
  ulong nx, ny, nz;
  
  if (P.nx % M.ncx != 0 || P.ny % M.ncy != 0 || P.nz % M.ncz != 0) {
    writeLogRF("Cannot divide lattice evenly...");
    throw new Exception("Lattice division exception");
  }

  nx = P.nx / M.ncx;
  ny = P.ny / M.ncy;
  nz = P.nz / M.ncz;

  writeLogRI("Initializing %d x %d x %d local lattice...", nx, ny, nz);

  L = Lattice(nx, ny, nz);

}


private:

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

