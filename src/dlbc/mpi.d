/// mpi.h -> mpi.d
module dlbc.mpi;

extern(C):

/* Aliases */
alias long MPI_Aint;
alias int  MPI_Comm;
alias int  MPI_Datatype;
alias int  MPI_Info;

/* Communicators */
immutable MPI_Comm MPI_COMM_WORLD = 0x44000000;

/* Datatypes */
immutable MPI_Datatype MPI_CHAR               = cast(MPI_Datatype) 0x4c000101;
immutable MPI_Datatype MPI_SIGNED_CHAR        = cast(MPI_Datatype) 0x4c000118;
immutable MPI_Datatype MPI_UNSIGNED_CHAR      = cast(MPI_Datatype) 0x4c000102;
immutable MPI_Datatype MPI_BYTE               = cast(MPI_Datatype) 0x4c00010d;
immutable MPI_Datatype MPI_WCHAR              = cast(MPI_Datatype) 0x4c00040e;
immutable MPI_Datatype MPI_SHORT              = cast(MPI_Datatype) 0x4c000203;
immutable MPI_Datatype MPI_UNSIGNED_SHORT     = cast(MPI_Datatype) 0x4c000204;
immutable MPI_Datatype MPI_INT                = cast(MPI_Datatype) 0x4c000405;
immutable MPI_Datatype MPI_UNSIGNED           = cast(MPI_Datatype) 0x4c000406;
immutable MPI_Datatype MPI_LONG               = cast(MPI_Datatype) 0x4c000807;
immutable MPI_Datatype MPI_UNSIGNED_LONG      = cast(MPI_Datatype) 0x4c000808;
immutable MPI_Datatype MPI_FLOAT              = cast(MPI_Datatype) 0x4c00040a;
immutable MPI_Datatype MPI_DOUBLE             = cast(MPI_Datatype) 0x4c00080b;
immutable MPI_Datatype MPI_LONG_DOUBLE        = cast(MPI_Datatype) 0x4c00100c;
immutable MPI_Datatype MPI_LONG_LONG_INT      = cast(MPI_Datatype) 0x4c000809;
immutable MPI_Datatype MPI_UNSIGNED_LONG_LONG = cast(MPI_Datatype) 0x4c000819;
immutable MPI_Datatype MPI_LONG_LONG          = MPI_LONG_LONG_INT;

immutable MPI_Datatype MPI_PACKED             = cast(MPI_Datatype) 0x4c00010f;
immutable MPI_Datatype MPI_LB                 = cast(MPI_Datatype) 0x4c000010;
immutable MPI_Datatype MPI_UB                 = cast(MPI_Datatype) 0x4c000011;

immutable int MPI_ANY_TAG = -1;
immutable int MPI_MAX_PROCESSOR_NAME = 128;

/* Statuses */
struct MPI_Status {
  int count;
  int cancelled;
  int MPI_SOURCE;
  int MPI_TAG;
  int MPI_ERROR;
}

/* Functions */
int MPI_Init(int*, char***);
int MPI_Comm_size(MPI_Comm, int*);
int MPI_Comm_rank(MPI_Comm, int*);
int MPI_Dims_create(int, int, int*);
int MPI_Cart_create(MPI_Comm, int, int*, int*, int, MPI_Comm*);
int MPI_Cart_get(MPI_Comm, int, int*, int*, int*);
int MPI_Cart_shift(MPI_Comm, int, int, int*, int*);

int MPI_Type_size(MPI_Datatype datatype, int *size);

int MPI_Get_processor_name(char*, int*);
int MPI_Get_version(int*, int*);

int MPI_Initialized(int*);
int MPI_Abort(MPI_Comm, int);
int MPI_Finalize();
int MPI_Finalized(int*);

int MPI_Address(void*, MPI_Aint*); // Deprecated
int MPI_Get_address(void *, MPI_Aint *);
int MPI_Type_create_struct(int, int*, MPI_Aint*, MPI_Datatype*, MPI_Datatype*);
int MPI_Type_commit(MPI_Datatype *);

int MPI_Type_create_hindexed(int count, const int array_of_blocklengths[],
                             const MPI_Aint array_of_displacements[], MPI_Datatype oldtype,
                             MPI_Datatype *newtype);
int MPI_Type_create_hvector(int count, int blocklength, MPI_Aint stride, MPI_Datatype oldtype,
                            MPI_Datatype *newtype);

int MPI_Type_contiguous(int, MPI_Datatype, MPI_Datatype *);
int MPI_Type_extent(MPI_Datatype, MPI_Aint *);

int MPI_Bcast(void*, int, MPI_Datatype, int, MPI_Comm);
int MPI_Send(const void*, int, MPI_Datatype, int, int, MPI_Comm);
int MPI_Recv(void*, int, MPI_Datatype, int, int, MPI_Comm, MPI_Status*);
// int MPI_Sendrecv(const void*, int, MPI_Datatype, int, int, void*, int, MPI_Datatype, int, int, MPI_Comm, MPI_Status*);
int MPI_Scatter(void* , int, MPI_Datatype, void*, int, MPI_Datatype, int, MPI_Comm);

// int MPI_Isend(const void *buf, int count, MPI_Datatype datatype, int dest, int tag,
//               MPI_Comm comm, MPI_Request *request);
// int MPI_Irecv(void *buf, int count, MPI_Datatype datatype, int source, int tag,
//               MPI_Comm comm, MPI_Request *request);

int MPI_Sendrecv(const void *sendbuf, int sendcount, MPI_Datatype sendtype, int dest,
                 int sendtag, void *recvbuf, int recvcount, MPI_Datatype recvtype,
                 int source, int recvtag, MPI_Comm comm, MPI_Status *status);

int MPI_Barrier(MPI_Comm);

