import logging;
import parameters;
import parallel;

import std.stdio;

import unstd.multidimarray;

Lattice L;

struct Lattice {
  int nx, ny, nz;
  Field!int red;
  Field!double blue;

  this ( MpiParams M, ParameterSet P ) {
    // Check if we can reconcile global lattice size with CPU grid
    if (P.nx % M.ncx != 0 || P.ny % M.ncy != 0 || P.nz % M.ncz != 0) {
      writeLogF("Cannot divide lattice evenly.");
    }

    // Calculate local lattice size
    int nx = cast(int) (P.nx / M.ncx);
    int ny = cast(int) (P.ny / M.ncy);
    int nz = cast(int) (P.nz / M.ncz);

    this.nx = nx;
    this.ny = ny;
    this.nz = nz;

    // Check for bogus halo
    if (P.haloSize < 1) {
      writeLogF("Halo size < 1 not allowed.");
    }

    blue = Field!double(nx, ny, nz, P.haloSize);
    red = Field!int(nx, ny, nz, P.haloSize);
  }
}

struct Field(T) {
  MultidimArray!(T, 3LU) arr, sbuffer, rbuffer;
  int nx, ny, nz;
  int nxH, nyH, nzH;
  int haloSize;

  MPI_Datatype mpiType = mpiTypeof!T;

  alias arr this;

  this (const int nx, const int ny, const int nz, const int haloSize) {
    writeLogRD("Initializing %d x %d x %d local field of type '%s' with halo of thickness %d.", nx, ny, nz, T.stringof, P.haloSize);
    this.nx = nx;
    this.ny = ny;
    this.nz = nz;
    this.haloSize = haloSize;
    this.nxH = haloSize + nx + haloSize;
    this.nyH = haloSize + ny + haloSize;
    this.nzH = haloSize + nz + haloSize;
    
    arr = multidimArray!T(nxH, nyH, nzH);
  }
 
  void haloExchange() {
    MPI_Status mpiStatus;

    // Send to positive x
    rbuffer = multidimArray!T(haloSize, nyH, nzH);
    sbuffer = arr[$-2*haloSize-1..$ - haloSize-1, 0..$, 0..$].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nyH * nzH, mpiType, M.nbx[1], 0, rbuffer._data.ptr, nyH * nzH, mpiType, M.nbx[0], 0, M.comm, &mpiStatus);
    arr[0..haloSize, 0..$, 0..$] = rbuffer;
    // owriteLogI(arr[0,1,0..$].toString());

    // Send to negative x
    sbuffer = arr[1..1+haloSize, 0..$, 0..$].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nyH * nzH, mpiType, M.nbx[0], 0, rbuffer._data.ptr, nyH * nzH, mpiType, M.nbx[1], 0, M.comm, &mpiStatus);
    arr[$ - haloSize .. $, 0..$, 0..$] = rbuffer;
    // owriteLogI(arr[$-1,1,0..$].toString());

    // Send to positive y
    rbuffer = multidimArray!T(nxH, haloSize, nzH);
    sbuffer = arr[0..$, $-2*haloSize-1..$ - haloSize-1, 0..$].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nxH * nzH, mpiType, M.nby[1], 0, rbuffer._data.ptr, nxH * nzH, mpiType, M.nby[0], 0, M.comm, &mpiStatus);
    arr[0..$, 0..haloSize, 0..$] = rbuffer;
    // owriteLogI(arr[1,0,0..$].toString());

    // Send to negative y
    rbuffer = arr[0..$, 1..1+haloSize, 0..$].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nxH * nzH, mpiType, M.nby[0], 0, rbuffer._data.ptr, nxH * nzH, mpiType, M.nby[1], 0, M.comm, &mpiStatus);
    arr[0..$, $ - haloSize .. $, 0..$] = rbuffer;
    // owriteLogI(arr[1, $-1,0..$].toString());

    // Send to positive z
    rbuffer = multidimArray!T(nxH, nyH, haloSize);
    sbuffer = arr[0..$, 0..$, $-2*haloSize-1..$ - haloSize-1].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nxH * nyH, mpiType, M.nbz[1], 0, rbuffer._data.ptr, nxH * nyH, mpiType, M.nbz[0], 0, M.comm, &mpiStatus);
    arr[0..$, 0..$, 0..haloSize] = rbuffer;
    // owriteLogI(arr[1,0,0..$].toString());

    // Send to negative z
    rbuffer = arr[0..$, 0..$, 1..1+haloSize].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nxH * nyH, mpiType, M.nbz[0], 0, rbuffer._data.ptr, nxH * nyH, mpiType, M.nbz[1], 0, M.comm, &mpiStatus);
    arr[0..$, 0..$, $ - haloSize .. $] = rbuffer;
    // owriteLogI(arr[1, $-1,0..$].toString());

    // writeLogRI(arr.toString());
  }

  void show(VL vl, LRF logRankFormat)() {
    writeLog!(vl, logRankFormat)(this.toString());
  }

  void showSlice(MultidimArray!(T, 2LU) slice) {
    foreach(row; slice.byTopDimension) {
      writeLogI(row.toString);
    }
  }

}

