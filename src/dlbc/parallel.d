// Written in the D programming language.

/**
   Functions that handle parallelisation through MPI.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.parallel;

public import dlbc.mpi;

import dlbc.logging;

/**
   Number of processes in the cardinal directions.
*/
@("param") int[] nc;

/**
   Show the topology after reordering the MPI communicator.
*/
@("param") bool showTopology;

/** 
    Dimensionality of the MPI grid.
*/
private enum dim = 3;

/**
   Parameters related to MPI are nicely packed into a globally available struct.
*/
MpiParams M;

/**
   Collection of parameters related to MPI.
*/
struct MpiParams {

  static immutable int root = 0;

  // MPI details
  int ver, subver;

  // Topology
  private int[dim] _nc;
  private int[dim] _c;
  private int[2][dim] _nb;

  /**
     Total number of processes.
  */
  int size;

  /**
     Vector containing the number of processes in each cardinal direction.
  */
  @property auto nc() {
    return _nc;
  }

  /**
     Number of processes in x-direction.
  */
  @property auto ncx() {
    return _nc[0];
  }

  /**
     Number of processes in y-direction.
  */
  @property auto ncy() {
    return _nc[1];
  }

  static if ( dim > 2 ) {
    /**
       Number of processes in z-direction.
    */
    @property auto ncz() {
      return _nc[2];
    }
  }

  /**
     Vector containing the ranks of neighbour processes in each cardinal direction.
  */
  @property auto nb() {
    return _nb;
  }

  /**
     Ranks of neighbour processes in x-direction.
  */

  @property auto nbx() {
    return _nb[0];
  }

  /**
     Ranks of neighbour processes in y-direction.
  */
  @property auto nby() {
    return _nb[1];
  }

  static if ( dim > 2 ) {
    /**
       Ranks of neighbour processes in z-direction.
    */
    @property auto nbz() {
      return _nb[2];
    }
  }

  /**
     Vector containing the coordinates of the process.
  */
  @property auto c() {
    return _c;
  }

  /**
     X-coordinate of the process.
  */
  @property auto cx() {
    return _c[0];
  }

  /**
     Y-coordinate of the process.
  */
  @property auto cy() {
    return _c[1];
  }

  static if ( dim > 2 ) {
    /**
       Z-coordinate of the process.
    */
    @property auto cz() {
      return _c[2];
    }
  }

  /**
     Rank of the process.
  */
  int rank;

  /** 
     MPI Communicator.
  */
  MPI_Comm comm;

  /** 
     Hostname of the host on which the process resides.
  */
  string hostname;

  /** 
     Keep track of whether MPI has been started yet.
  */
  bool hasStarted = false;

  /** 
     Returns whether the current process is the root process.
  */
  bool isRoot() @property {
    return ( rank == root );
  }

  /**
     Show information about the layout of the grid of processes.
  */
  void show(VL vl)() {
    writeLog!(vl, LRF.Root)("Currently using %d CPUs on a %s grid.", size, makeLengthsString(nc));
    writeLog!(vl, LRF.Ordered)("Rank %d is running on host '%s' at position (%d, %d, %d):", rank, hostname, cx, cy, cz);
    writeLog!(vl, LRF.Ordered)("Neighbours:\nx %#6.6d %#6.6d %#6.6d\ny %#6.6d %#6.6d %#6.6d\nz %#6.6d %#6.6d %#6.6d", nbx[0], rank, nbx[1], nby[0], rank, nby[1], nbz[0], rank, nbz[1]);
  }
}

/** 
    Initializes barebones MPI communicator.

    Params:
      args = command line arguments
*/
void startMpi(const string[] args) {
  import std.conv, std.string, std.algorithm, std.array;

  // Only run once
  if ( M.hasStarted ) {
    return;
  }

  int rank, size;
  MPI_Comm commWorld = MPI_COMM_WORLD;

  int argc = cast(int) args.length;
  char** argv = cast(char**)map!(toStringz)(args).array.ptr;

  // For hostnames
  auto pname = new char[](MPI_MAX_PROCESSOR_NAME + 1);
  int pnlen;

  MPI_Init( &argc, &argv );
  MPI_Comm_rank( commWorld, &rank );
  MPI_Comm_size( commWorld, &size );

  // Set values in global MPI parameter struct
  M.rank = rank;
  M.size = size;
  M.comm = commWorld;

  MPI_Get_version( &M.ver, &M.subver );

  MPI_Get_processor_name( pname.ptr, &pnlen );
  M.hostname = to!string(pname[0..pnlen]);

  M.hasStarted = true;
  writeLogRN("\nInitialized MPI v%d.%d on %d CPUs.", M.ver, M.subver, M.size);
}

/**
   Reorders MPI to use a cartesian grid based on the suggestion parallel.nc.
*/
void reorderMpi() {
  int rank, size;
  int[dim] dims;
  int[dim] periodic = [ true , true , true ];
  int[dim] pos;
  int reorder = true;
  int srcRank, destRank;
  MPI_Comm comm;

  if ( nc.length == 0 ) {
    dims[] = 0;
  }
  else if ( nc.length == dim ) {
    dims = nc;
  }
  else {
    writeLogF("Array variable parallel.nc must have length %d.", dim);
  }

  writeLogRD("Creating MPI dims from suggestion %s.", makeLengthsString(dims));

  // Create cartesian grid of dimensions ( ncx * ncy * ncz )
  MPI_Dims_create(M.size, dim, dims.ptr);
  M._nc = dims;

  writeLogRN("Reordering MPI communicator to form a %s grid.", makeLengthsString(M.nc));

  // Create a new communicator with the grid
  MPI_Cart_create(M.comm, dim, dims.ptr, periodic.ptr, reorder, &comm);
  M.comm = comm;

  // Recalculate rank (size shouldn't change)
  MPI_Comm_rank( M.comm, &rank );
  MPI_Comm_size( M.comm, &size );
  M.rank = rank;
  assert(M.size == size);
  M.size = size;

  // Get position in the cartesian grid
  MPI_Cart_get(M.comm, dim, dims.ptr, periodic.ptr, pos.ptr);
  M._c = pos;

  // Calculate nearest neighbours
  for ( uint i = 0; i < dim ; i++ ) {
    MPI_Cart_shift(M.comm, i, 1, &srcRank, &destRank);
    M._nb[i][0] = srcRank;
    M._nb[i][1] = destRank;
  }

  writeLogRD("Finished reordering MPI communicator.");
  if (showTopology) {
    M.show!(VL.Information);
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
MPI_Datatype mpiTypeof(T)() {
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
auto mpiLengthof(T)() {
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
  if ( ! M.isRoot ) {
    str = to!string(strbuf[0..strlen]);
  }
}

