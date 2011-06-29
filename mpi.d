module mpi;

extern(C):

/* Communicators */
alias int MPI_Comm;
const MPI_Comm MPI_COMM_WORLD = 0x44000000;
//#define MPI_COMM_WORLD ((MPI_Comm)0x44000000)
//#define MPI_COMM_SELF  ((MPI_Comm)0x44000001)


int MPI_Init(int *, char ***);
int MPI_Comm_size(MPI_Comm, int *);
int MPI_Comm_rank(MPI_Comm, int *);

int MPI_Barrier(MPI_Comm);

int MPI_Finalize();
int MPI_Initialized(int *);
int MPI_Abort(MPI_Comm, int);
