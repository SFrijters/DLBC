import logging;
import parameters;
import parallel;

import unstd.multidimarray;

struct Field(T, uint dim, uint veclen = 1) {
  static assert(dim == 3, "Non-3D fields not yet implemented.");
  static assert(veclen >= 1, "Vector length of field must be 1 or larger.");

  static if ( veclen > 1 ) {
    MultidimArray!(T, dim + 1) arr, sbuffer, rbuffer;
  }
  else {
    MultidimArray!(T, dim) arr, sbuffer, rbuffer;
  }

  private uint _dimensions = dim;
  private uint[dim] _lengths;
  private uint _nxH, _nyH, _nzH, _haloSize;

  @property auto dimensions() {
    return _dimensions;
  }

  @property auto lengths() {
    return _lengths;
  }

  @property auto nx() {
    return _lengths[0];
  }

  @property auto ny() {
    return _lengths[1];
  }

  @property auto nz() {
    return _lengths[2];
  }

  @property auto nxH() {
    return _nxH;
  }

  @property auto nyH() {
    return _nyH;
  }

  @property auto nzH() {
    return _nzH;
  }

  @property auto haloSize() {
    return _haloSize;
  }

  MPI_Datatype mpiType = mpiTypeof!T;

  alias arr this;

  this (const uint[dim] lengths, const uint haloSize) {
    writeLogRD("Initializing %d x %d x %d local field of type '%s' with halo of thickness %d.", lengths[0], lengths[1], lengths[2], T.stringof, P.haloSize);

    this._lengths = lengths;
    this._haloSize = haloSize;
    this._nxH = haloSize + nx + haloSize;
    this._nyH = haloSize + ny + haloSize;
    this._nzH = haloSize + nz + haloSize;
    
    static if ( veclen > 1 ) {
      arr = multidimArray!T(nxH, nyH, nzH, veclen);
    }
    else {
      arr = multidimArray!T(nxH, nyH, nzH);
    }

    writeLogRD("Dimensions: %d.", this.dimensions);
  }
 
  void haloExchange() {
    import std.conv: to;

    int buflen;
    MPI_Status mpiStatus;

    writeLogRD("Halo exchange...");

    static if ( veclen > 1 ) {
      // Send to positive x
      buflen = to!int(nyH * nzH * veclen);
      rbuffer = multidimArray!T(haloSize, nyH, nzH, veclen);
      sbuffer = arr[$-2*haloSize-1..$ - haloSize-1, 0..$, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, M.comm, &mpiStatus);
      arr[0..haloSize, 0..$, 0..$, 0..$] = rbuffer;
      // Send to negative x
      sbuffer = arr[1..1+haloSize, 0..$, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, M.comm, &mpiStatus);
      arr[$ - haloSize .. $, 0..$, 0..$, 0..$] = rbuffer;

      // Send to positive y
      buflen = to!int(nxH * nzH * veclen);
      rbuffer = multidimArray!T(nxH, haloSize, nzH, veclen);
      sbuffer = arr[0..$, $-2*haloSize-1..$ - haloSize-1, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, M.comm, &mpiStatus);
      arr[0..$, 0..haloSize, 0..$, 0..$] = rbuffer;
      // Send to negative y
      rbuffer = arr[0..$, 1..1+haloSize, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, M.comm, &mpiStatus);
      arr[0..$, $ - haloSize .. $, 0..$, 0..$] = rbuffer;

      // Send to positive z
      buflen = to!int(nxH * nyH * veclen);
      rbuffer = multidimArray!T(nxH, nyH, haloSize, veclen);
      sbuffer = arr[0..$, 0..$, $-2*haloSize-1..$ - haloSize-1, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbz[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nbz[0], 0, M.comm, &mpiStatus);
      arr[0..$, 0..$, 0..haloSize, 0..$] = rbuffer;
      // Send to negative z
      rbuffer = arr[0..$, 0..$, 1..1+haloSize, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbz[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nbz[1], 0, M.comm, &mpiStatus);
      arr[0..$, 0..$, $ - haloSize .. $, 0..$] = rbuffer;
    }  
    else {
      // Send to positive x
      buflen = to!int(nyH * nzH);
      rbuffer = multidimArray!T(haloSize, nyH, nzH);
      sbuffer = arr[$-2*haloSize-1..$ - haloSize-1, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, M.comm, &mpiStatus);
      arr[0..haloSize, 0..$, 0..$] = rbuffer;
      // Send to negative x
      sbuffer = arr[1..1+haloSize, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, M.comm, &mpiStatus);
      arr[$ - haloSize .. $, 0..$, 0..$] = rbuffer;

      // Send to positive y
      buflen = to!int(nxH * nzH);
      rbuffer = multidimArray!T(nxH, haloSize, nzH);
      sbuffer = arr[0..$, $-2*haloSize-1..$ - haloSize-1, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, M.comm, &mpiStatus);
      arr[0..$, 0..haloSize, 0..$] = rbuffer;
      // Send to negative y
      rbuffer = arr[0..$, 1..1+haloSize, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, M.comm, &mpiStatus);
      arr[0..$, $ - haloSize .. $, 0..$] = rbuffer;

      // Send to positive z
      buflen = to!int(nxH * nyH);
      rbuffer = multidimArray!T(nxH, nyH, haloSize);
      sbuffer = arr[0..$, 0..$, $-2*haloSize-1..$ - haloSize-1].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbz[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nbz[0], 0, M.comm, &mpiStatus);
      arr[0..$, 0..$, 0..haloSize] = rbuffer;
      // Send to negative z
      rbuffer = arr[0..$, 0..$, 1..1+haloSize].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbz[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nbz[1], 0, M.comm, &mpiStatus);
      arr[0..$, 0..$, $ - haloSize .. $] = rbuffer;
    }
  }

  void show(VL vl, LRF logRankFormat)() {
    static if ( dim <= 3 ) {
      writeLog!(vl, logRankFormat)(this.toString());
    }
    else if ( dim == 4 ) {
      foreach(row; this.byTopDimension) {
        writeLog!(vl, logRankFormat)(row.toString());
      }
    }
    else {
      static assert(false, "Show vector array not yet implemented for dim + vec > 4.");
    }
  }

}

