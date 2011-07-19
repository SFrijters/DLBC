import parameters;
import stdio;
public import mpi;

const int D = 3;

MPI_Datatype parameterSetMpiType;

/// Need to define a charlength to easily transmit strings over MPI
alias char[256] MpiString;
immutable string MpiStringType = "char[256]";
immutable int MpiStringLength = 256;

alias MpiParams M;
struct MpiParams {

  static const int root = 0;

  // MPI details
  static int ver, subver;

  // Topology  
  static int ncx, ncy, ncz;
  static int size;

  // CPU rank
  static int rank;

  // CPU position
  static int cx, cy, cz;

  // Nearest neighbours

  static int nbx[2];
  static int nby[2];
  static int nbz[2];

  // Communicator
  static MPI_Comm comm;
  
  static void show() {
    writeLogI("Report from rank %d at position (%d, %d, %d):", rank, cx, cy, cz);
    writeLogI("  Currently using %d CPUs on a %d x %d x %d grid.", size, ncx, ncy, ncz);
    writeLogI("  Neighbours x: %#6.6d %#6.6d %#6.6d.", nbx[0], rank, nbx[1]);
    writeLogI("  Neighbours y: %#6.6d %#6.6d %#6.6d.", nby[0], rank, nby[1]);
    writeLogI("  Neighbours z: %#6.6d %#6.6d %#6.6d.", nbz[0], rank, nbz[1]);
  }
}

/// Initializes barebones MPI communicator
void startMpi() {
  int rank, size;
  MPI_Comm commWorld = MPI_COMM_WORLD;
  // C-style dummy arg vector for MPI_Init
  int    argc = 0;
  char** argv = null;

  MPI_Init( &argc, &argv );
  MPI_Comm_rank( commWorld, &rank );
  MPI_Comm_size( commWorld, &size );

  // Set values in global MPI parameter struct
  M.rank = rank;
  M.size = size;
  M.comm = commWorld;

  MPI_Get_version( &M.ver, &M.subver );

  writeLogRN("\nInitialized MPI v%d.%d on %d CPUs.", M.ver, M.subver, M.size);
}

/// Reorders MPI to use a cartesian grid
void reorderMpi() {
  int rank, size;
  int[D] dims;
  int[D] periodic = [ true , true , true ];
  int[D] pos;
  int reorder = true;
  int srcRank, destRank;
  MPI_Comm comm;

  writeLogRD("Creating MPI dims from suggestion %d x %d x %d.", P.ncx, P.ncy, P.ncz);

  dims[0] = P.ncx;
  dims[1] = P.ncy;
  dims[2] = P.ncz;

  // Create cartesian grid of dimensions ( ncx * ncy * ncz )

  MPI_Dims_create(M.size, D, dims.ptr);
  M.ncx = dims[0];
  M.ncy = dims[1];
  M.ncz = dims[2];

  writeLogRN("Reordering MPI communicator to form a %d x %d x %d grid.", M.ncx, M.ncy, M.ncz );

  // Create a new communicator with the grid
  MPI_Cart_create(M.comm, D, dims.ptr, periodic.ptr, reorder, &comm);
  M.comm = comm;

  // Recalculate rank (size shouldn't change)
  MPI_Comm_rank( M.comm, &rank );
  MPI_Comm_size( M.comm, &size );
  M.rank = rank;
  M.size = size;

  // Get position in the cartesian grid
  MPI_Cart_get(M.comm, D, dims.ptr, periodic.ptr, pos.ptr);
  M.cx = pos[0];
  M.cy = pos[1];
  M.cz = pos[2];

  // Calculate nearest neighbours in x-direction
  MPI_Cart_shift(M.comm, 0, 1, &srcRank, &destRank);
  M.nbx[0] = srcRank;
  M.nbx[1] = destRank;

  // Calculate nearest neighbours in y-direction
  MPI_Cart_shift(M.comm, 1, 1, &srcRank, &destRank);
  M.nby[0] = srcRank;
  M.nby[1] = destRank;

  // Calculate nearest neighbours in z-direction
  MPI_Cart_shift(M.comm, 2, 1, &srcRank, &destRank);
  M.nbz[0] = srcRank;
  M.nbz[1] = destRank;

  writeLogRD("Finished reordering MPI communicator.");

}

void endMpi() {
  writeLogRN("Finalized MPI.");
  MPI_Finalize();
}
