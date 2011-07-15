import stdio;

const int D = 3;

MPI_Datatype parameterListMpiType;

struct MpiParams {
  
  // Topology  
  int ncx, ncy, ncz;
  int size;

  // CPU rank
  int rank;

  // CPU position
  int cx;
  int cy;
  int cz;

  // Nearest neighbours

  int nbx[2];
  int nby[2];
  int nbz[2];

  // Communicator
  MPI_Comm comm;
  
  void show() {
    writelog();
    writelog("Report from rank %d at position (%d, %d, %d):",rank,cx,cy,cz);
    writelog("  Currently using %d CPUs on a %d x %d x %d grid.",size,ncx,ncy,ncz);
    writelog("  Neighbours x: %#6.6d %#6.6d %#6.6d.",nbx[0],rank,nbx[1]);
    writelog("  Neighbours y: %#6.6d %#6.6d %#6.6d.",nby[0],rank,nby[1]);
    writelog("  Neighbours z: %#6.6d %#6.6d %#6.6d.",nbz[0],rank,nbz[1]);
  }
}

MpiParams M;

/// Initializes barebones MPI communicator
void startMpi() {
  int rank, size;
  // C-style dummy arg vector for MPI_Init
  int    argc = 0;
  char** argv = null;

  MPI_Init( &argc, &argv );
  MPI_Comm_rank( MPI_COMM_WORLD, &rank );
  MPI_Comm_size( MPI_COMM_WORLD, &size );

  M.rank = rank;
  M.size = size;
  M.comm = MPI_COMM_WORLD;
}

/// Reorders MPI to use a cartesian grid
void reorderMpi() {
  int rank, size;
  int[D] dims;
  int[D] periodic = [ true , true , true ];
  int[D] pos;
  int srcRank, destRank;
  MPI_Comm comm;

  // Create cartesian grid of dimensions ( ncx * ncy * ncz )
  MPI_Dims_create(M.size,D,dims.ptr);
  M.ncx = dims[0];
  M.ncy = dims[1];
  M.ncz = dims[2];

  // Create a new communicator with the grid
  MPI_Cart_create(M.comm, D, dims.ptr, periodic.ptr, true, &comm);
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
}

void endMpi() {
  MPI_Finalize();
}


/// mpi.h -> mpi.d

extern(C):

/* Communicators */
alias int MPI_Comm;
const MPI_Comm MPI_COMM_WORLD = 0x44000000;

alias long MPI_Aint;
int MPI_Address(void*, MPI_Aint *);
int MPI_Type_struct(int, int *, MPI_Aint *, MPI_Datatype *, MPI_Datatype *);
int MPI_Type_commit(MPI_Datatype *);
int MPI_Scatter(void* , int, MPI_Datatype, void*, int, MPI_Datatype, int, MPI_Comm);

/* Datatypes */
alias int MPI_Datatype;
const MPI_Datatype MPI_CHAR           = cast(MPI_Datatype) 0x4c000101;
const MPI_Datatype MPI_SIGNED_CHAR    = cast(MPI_Datatype) 0x4c000118;
const MPI_Datatype MPI_UNSIGNED_CHAR  = cast(MPI_Datatype) 0x4c000102;
const MPI_Datatype MPI_BYTE           = cast(MPI_Datatype) 0x4c00010d;
const MPI_Datatype MPI_WCHAR          = cast(MPI_Datatype) 0x4c00040e;
const MPI_Datatype MPI_SHORT          = cast(MPI_Datatype) 0x4c000203;
const MPI_Datatype MPI_UNSIGNED_SHORT = cast(MPI_Datatype) 0x4c000204;
const MPI_Datatype MPI_INT            = cast(MPI_Datatype) 0x4c000405;
const MPI_Datatype MPI_UNSIGNED       = cast(MPI_Datatype) 0x4c000406;
const MPI_Datatype MPI_LONG           = cast(MPI_Datatype) 0x4c000807;
const MPI_Datatype MPI_UNSIGNED_LONG  = cast(MPI_Datatype) 0x4c000808;
const MPI_Datatype MPI_FLOAT          = cast(MPI_Datatype) 0x4c00040a;
const MPI_Datatype MPI_DOUBLE         = cast(MPI_Datatype) 0x4c00080b;
const MPI_Datatype MPI_LONG_DOUBLE    = cast(MPI_Datatype) 0x4c00100c;
const MPI_Datatype MPI_LONG_LONG_INT  = cast(MPI_Datatype) 0x4c000809;
const MPI_Datatype MPI_UNSIGNED_LONG_LONG = cast(MPI_Datatype) 0x4c000819;
const MPI_Datatype MPI_LONG_LONG      = MPI_LONG_LONG_INT;

const MPI_Datatype MPI_PACKED         = cast(MPI_Datatype) 0x4c00010f;
const MPI_Datatype MPI_LB             = cast(MPI_Datatype) 0x4c000010;
const MPI_Datatype MPI_UB             = cast(MPI_Datatype) 0x4c000011;

/* Functions */
int MPI_Init(int *, char ***);
int MPI_Comm_size(MPI_Comm, int *);
int MPI_Comm_rank(MPI_Comm, int *);
int MPI_Dims_create(int, int, int *);
int MPI_Cart_create(MPI_Comm, int, int *, int *, int, MPI_Comm *);
int MPI_Cart_get(MPI_Comm, int, int *, int *, int *);
int MPI_Cart_shift(MPI_Comm, int, int, int *, int *);

int MPI_Barrier(MPI_Comm);

int MPI_Finalize();
int MPI_Initialized(int *);
int MPI_Abort(MPI_Comm, int);

int MPI_Send(void*, int, MPI_Datatype, int, int, MPI_Comm);
int MPI_Recv(void*, int, MPI_Datatype, int, int, MPI_Comm, MPI_Status *);

struct MPI_Status {
    int count;
    int cancelled;
    int MPI_SOURCE;
    int MPI_TAG;
    int MPI_ERROR;

}

