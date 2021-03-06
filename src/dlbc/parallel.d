// Written in the D programming language.

/**
   Functions that handle parallelisation through MPI.

   Copyright: Stefan Frijters 2011-2015

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

*/

module dlbc.parallel;

public import dlbc.mpi;

import dlbc.logging;
import dlbc.lb.connectivity: gconn;

/**
   Number of processes in the cardinal directions.
*/
@("param") int[] nc;

/**
   Show the topology after reordering the MPI communicator.
*/
@("param") bool showTopology;

/**
   Parameters related to MPI are nicely packed into a globally available struct.
*/
MpiParams!(gconn.d) M;

private bool mpiHasStarted = false;

/**
   Collection of parameters related to MPI.
*/
struct MpiParams(uint d) {
  enum dim = d;
  private {
    int _ver, _subver;
    int[dim] _nc;
    int[dim] _c;
    int[2][dim] _nb;
    int _size;
    int _rank;
    MPI_Comm _comm;
    string _hostname;
  }

  /**
     Rank of the root process
  */
  static immutable int root = 0;

  /**
     Total number of processes.
  */
  @property const size() @safe pure nothrow {
    return _size;
  }

  /**
     Vector containing the number of processes in each cardinal direction.
  */
  @property const nc() @safe pure nothrow {
    return _nc;
  }

  /**
     Vector containing the ranks of neighbour processes in each cardinal direction.
  */
  @property const nb() @safe pure nothrow {
    return _nb;
  }

  /**
     Vector containing the coordinates of the process.
  */
  @property const c() @safe pure nothrow {
    return _c;
  }

  /**
     Rank of the process.
  */
  @property const rank() @safe pure nothrow {
    return _rank;
  }

  /**
     MPI Communicator.
  */
  @property const comm() @safe pure nothrow {
    return _comm;
  }

  /**
     Hostname of the host on which the process resides.
  */
  @property const hostname() @safe pure nothrow {
    return _hostname;
  }

  /**
     MPI version
  */
  @property const ver() @safe pure nothrow {
    return _ver;
  }

  /**
     MPI subversion
  */
  @property const subver() @safe pure nothrow {
    return _subver;
  }

  /**
     Returns whether the current process is the root process.
  */
  @property bool isRoot() @safe pure nothrow {
    return ( rank == root );
  }

  /**
     Show information about the layout of the grid of processes.
  */
  void show(VL vl)() {
    import std.string: format;
    writeLog!(vl, LRF.Root)("Currently using %d CPUs on a %s grid.", size, makeLengthsString(nc));
    writeLog!(vl, LRF.Ordered)("Rank %d is running on host '%s' at position %s:", rank, hostname, c);
    string neighbours = "Neighbours:\n";
    foreach(immutable i, nbpair; nb) {
      neighbours ~= format("%s %#6.6d %#6.6d %#6.6d\n", dimstr[i], nbpair[0], rank, nbpair[1]);
    }
    writeLog!(vl, LRF.Ordered)(neighbours);
  }
}

/** 
    Initializes barebones MPI communicator.

    Params:
      M = MPI parameter struct
      args = command line arguments
*/
void startMpi(T)(ref T M, in string[] args) if ( isMpiParams!T ) {
  import std.conv, std.string, std.algorithm, std.array;

  // Only run once
  if ( mpiHasStarted ) {
    return;
  }

  int rank, size;
  MPI_Comm commWorld = MPI_COMM_WORLD;

  int argc = cast(int) args.length;
  char** argv = cast(char**)map!(toStringz)(args).array().ptr;

  // For hostnames
  auto pname = new char[](MPI_MAX_PROCESSOR_NAME + 1);

  MPI_Init( &argc, &argv );
  MPI_Comm_rank( commWorld, &rank );
  MPI_Comm_size( commWorld, &size );

  // Set values in global MPI parameter struct
  M._rank = rank;
  M._size = size;
  M._comm = commWorld;

  MPI_Get_version( &M._ver, &M._subver );

  int pnlen;
  MPI_Get_processor_name( pname.ptr, &pnlen );
  M._hostname = to!string(pname[0..pnlen]);

  mpiHasStarted = true;
  writeLogRN("\nInitialized MPI v%d.%d on %d CPUs.", M.ver, M.subver, M.size);
}

/**
   Reorders MPI to use a cartesian grid based on the suggestion parallel.nc.
*/
void reorderMpi(T)(ref T M, int[] nc) if ( isMpiParams!T ) {
  import dlbc.parameters: checkArrayParameterLength;
  import dlbc.range: Iota;
  int rank, size;
  int[M.dim] dims;
  int[M.dim] periodic = true;
  int[M.dim] pos;
  int reorder = true;
  int srcRank, destRank;
  MPI_Comm comm;

  checkArrayParameterLength(nc, "parallel.nc", M.dim);

  writeLogRD("Creating MPI dims from suggestion %s.", makeLengthsString(dims));

  // Create cartesian grid of dimensions 'dims'
  MPI_Dims_create(M.size, M.dim, dims.ptr);
  M._nc = dims;

  writeLogRN("Reordering MPI communicator to form a %s grid.", makeLengthsString(M.nc));

  // Create a new communicator with the grid
  MPI_Cart_create(M.comm, M.dim, dims.ptr, periodic.ptr, reorder, &comm);
  M._comm = comm;

  // Recalculate rank (size shouldn't change)
  MPI_Comm_rank( M.comm, &rank );
  MPI_Comm_size( M.comm, &size );
  M._rank = rank;
  assert(M.size == size);
  M._size = size;

  // Get position in the cartesian grid
  MPI_Cart_get(M.comm, M.dim, dims.ptr, periodic.ptr, pos.ptr);
  M._c = pos;

  // Calculate nearest neighbours
  foreach(immutable i; Iota!(0, M.dim) ) {
    MPI_Cart_shift(M.comm, i, 1, &srcRank, &destRank);
    M._nb[i][0] = srcRank;
    M._nb[i][1] = destRank;
  }

  writeLogRD("Finished reordering MPI communicator.");
  if (showTopology) {
    M.show!(VL.Information)();
  }
}

/**
   Shuts down MPI.
*/
void endMpi() {
  writeLogRN("Finalized MPI.");
  MPI_Finalize();
}

/**
   Wrapper for MPI_Barrier based on the current communicator.
*/
int MpiBarrier() {
  return MPI_Barrier(M.comm);
}

/**
   Translates a datatype into its matching MPI_Datatype.

   Params:
     T = type to be translated

   Returns:
     The MPI_Datatype matching T.
*/
MPI_Datatype mpiTypeof(T)() @property {
  import dlbc.range;
  import std.traits;
  static if ( isArray!T ) {
    return mpiTypeof!(BaseElementType!T);
  }
  else {
    static if ( is(T : int) ) { // this now also accepts enum
      return MPI_INT;
    }
    else static if ( is(T : ulong) ) {
      return MPI_UNSIGNED_LONG;
    }
    else static if ( is(T == double) ) {
      return MPI_DOUBLE;
    }
    else static if ( is(T == bool) ) {
      return MPI_BYTE;
    }
    else {
      static assert(0, "Datatype not implemented for MPI.");
    }
  }
}

/**
   Get the size of a data type, to be used in MPI calls.

   Params:
     T = type

   Returns:
     The length of T if it is a range, or 1 otherwise.
*/
auto mpiLengthof(T)() @property {
  import std.conv: to;
  import dlbc.range;
  return to!uint(LengthOf!T);
}

/**
   Broadcast a string over MPI.

   Params:
     str = string to be broadcast
*/
void MpiBcastString(ref string str) {
  import std.conv: to;

  char[] strbuf;  
  int strlen = to!int(str.length);
  MPI_Bcast(&strlen, 1, MPI_INT, M.root, M.comm);
  strbuf.length = strlen;
  if ( M.isRoot() ) {
    strbuf[0..strlen] = str;
  }
  MPI_Bcast(strbuf.ptr, strlen, MPI_CHAR, M.root, M.comm);
  if ( ! M.isRoot() ) {
    str = to!string(strbuf[0..strlen]);
  }
}

/**
   Broadcast any parameter over MPI.

   Params:
     parameter = parameter to be broadcast
*/
void broadcastParameter(T)(ref T parameter) {
  import std.traits;
  import std.conv: to;
  int arrlen;
  static if ( is( T == string) ) {
    MpiBcastString(parameter);
  }
  else {
    static if ( isArray!T ) {
      arrlen = to!int(parameter.length);
      MPI_Bcast(&arrlen, 1, mpiTypeof!(typeof(arrlen)), M.root, M.comm);
      parameter.length = arrlen;
      static if ( is (typeof(parameter[0]) == string ) ) {
        foreach(immutable i; 0..arrlen ) {
          MpiBcastString(parameter[i]);
        }
      }
      else static if ( isArray!(typeof(parameter[0])) ) {
        foreach(ref p; parameter) {
          broadcastParameter(p);
        }
      }
      else {
        MPI_Bcast(parameter.ptr, arrlen, mpiTypeof!T, M.root, M.comm);
      }
    }
    else {
      MPI_Bcast(&parameter, 1, mpiTypeof!T, M.root, M.comm);
    }
  }
}

/**
   Template to check if a type is MpiParams.

   Params:
     T = type to check
*/
template isMpiParams(T) {
  enum isMpiParams = is(T == MpiParams!d, uint d);
}
