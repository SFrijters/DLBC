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

