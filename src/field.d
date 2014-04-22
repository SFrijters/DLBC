// Written in the D programming language.

/**
Implementation of scalar and vector fields on the lattice.

Copyright: Stefan Frijters 2011-2014

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module field;

import logging;
import parameters;
import parallel;

import unstd.multidimarray;

/**
The $(D Field) struct is designed as a template to hold scalars of vectors of
arbitrary type on a lattice of arbitrary dimension (this will normally match
the dimensionality of the underlying $(D Lattice) struct).

Params:
  T = datatype to be held
  dim = dimensionality of the field
  veclen = length of the vector to be stored at every point; a value of 1
    corresponds to a scalar and is treated as a special case
           
*/
struct Field(T, uint dim, uint veclen = 1) {
  static assert(dim > 1, "1D fields are not supported.");
  static assert(dim == 3, "Non-3D fields not yet implemented.");
  static assert(veclen >= 1, "Vector length of field must be 1 or larger.");

  static if ( veclen > 1 ) {
    /**
    Data of the field, which necessitates an extra dimension of the underlying array if it's a vector.
    */
    MultidimArray!(T, dim + 1) arr;
    /**
    MPI send buffer for data of the field, which necessitates an extra dimension of the underlying array if it's a vector.
    */
    MultidimArray!(T, dim + 1) sbuffer;
    /**
    MPI receive buffer for data of the field, which necessitates an extra dimension of the underlying array if it's a vector.
    */
    MultidimArray!(T, dim + 1) rbuffer;
  }
  else {
    MultidimArray!(T, dim) arr, sbuffer, rbuffer;
  }

  private uint _dimensions = dim;
  private uint[dim] _lengths;
  private uint[dim] _lengthsH;
  private uint _nxH, _nyH, _nzH, _haloSize;

  /**
     Number of dimensions of the field.
  */
  @property auto dimensions() {
    return _dimensions;
  }

  /**
     Lengths of the physical dimensions of the field.
  */
  @property auto lengths() {
    return _lengths;
  }

  /**
     Alias for the first component of $(D lengths).
  */
  @property auto nx() {
    return _lengths[0];
  }

  /**
     Alias for the second component of $(D lengths).
  */
  @property auto ny() {
    return _lengths[1];
  }

  /**
     Alias for the third component of $(D lengths), if $(D dim) > 2.
  */
  static if ( dim > 2 ) {
    @property auto nz() {
      return _lengths[2];
    }
  }

  /**
     Size of the halo (on each side).
  */
  @property auto haloSize() {
    return _haloSize;
  }

  /**
     Length of the physical dimensions with added halo on both sides, i.e. the stored field.
  */
  @property auto lengthsH() {
    return _lengthsH;
  }

  /**
     Alias for the first component of $(D lengthsH).
  */
  @property auto nxH() {
    return _lengthsH[0];
  }

  /**
     Alias for the second component of $(D lengthsH).
  */
  @property auto nyH() {
    return _lengthsH[1];
  }

  /**
     Alias for the third component of $(D lengthsH), if $(D dim) > 2.
  */
  static if ( dim > 2 ) {
    @property auto nzH() {
      return _lengthsH[2];
    }
  }

  /**
     MPI datatype corresponding to type $(D T).
  */
  private MPI_Datatype mpiType = mpiTypeof!T;

  /**
     Allows to access the underlying multidimensional array correctly.
  */
  alias arr this;


  /**
     A $(D Field) is constructed by specifying the size of the physical domain and the required halo size.
     
     Params:
       lengths = lengths of the dimensions of the physical domain
       haloSize = size of the halo region
  */
  this (const uint[dim] lengths, const uint haloSize) {
    writeLogRD("Initializing %s local field of type '%s' with halo of thickness %d.", lengths.makeLengthsString, T.stringof, P.haloSize);

    this._lengths = lengths;
    this._haloSize = haloSize;
    // Why doesn't scalar addition work?
    this._lengthsH[0] = lengths[0] + (2* haloSize);
    this._lengthsH[1] = lengths[1] + (2* haloSize);
    this._lengthsH[2] = lengths[2] + (2* haloSize);

    static if ( veclen > 1 ) {
      arr = multidimArray!T(nxH, nyH, nzH, veclen);
    }
    else {
      // Special case for scalars.
      arr = multidimArray!T(nxH, nyH, nzH);
    }
  }

  /**
     The halo of the field is exchanged with all 6 neighbours, according to the haloSize specified when the field was created.
     The data is first stored in the send buffer $(D sbuffer), and data from the neighbours is received in $(D rbuffer).
     Because the slicing is performed in an identical fashion on all processes, we can easily put the data in the correct
     spot in the main array.

     A special case exists again for scalar data, because the $(D multidimArray) doesn't have a fourth dimension.
  */
  void haloExchange() {
    int buflen;
    MPI_Status mpiStatus;

    static if ( veclen > 1 ) {
      // Send to positive x
      buflen = nyH * nzH * veclen;
      rbuffer = multidimArray!T(haloSize, nyH, nzH, veclen);
      sbuffer = arr[$-2*haloSize-1..$ - haloSize-1, 0..$, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, M.comm, &mpiStatus);
      arr[0..haloSize, 0..$, 0..$, 0..$] = rbuffer;
      // Send to negative x
      sbuffer = arr[1..1+haloSize, 0..$, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, M.comm, &mpiStatus);
      arr[$ - haloSize .. $, 0..$, 0..$, 0..$] = rbuffer;

      // Send to positive y
      buflen = nxH * nzH * veclen;
      rbuffer = multidimArray!T(nxH, haloSize, nzH, veclen);
      sbuffer = arr[0..$, $-2*haloSize-1..$ - haloSize-1, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, M.comm, &mpiStatus);
      arr[0..$, 0..haloSize, 0..$, 0..$] = rbuffer;
      // Send to negative y
      rbuffer = arr[0..$, 1..1+haloSize, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, M.comm, &mpiStatus);
      arr[0..$, $ - haloSize .. $, 0..$, 0..$] = rbuffer;

      // Send to positive z
      buflen = nxH * nyH * veclen;
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
      buflen = nyH * nzH;
      rbuffer = multidimArray!T(haloSize, nyH, nzH);
      sbuffer = arr[$-2*haloSize-1..$ - haloSize-1, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, M.comm, &mpiStatus);
      arr[0..haloSize, 0..$, 0..$] = rbuffer;
      // Send to negative x
      sbuffer = arr[1..1+haloSize, 0..$, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, M.comm, &mpiStatus);
      arr[$ - haloSize .. $, 0..$, 0..$] = rbuffer;

      // Send to positive y
      buflen = nxH * nzH;
      rbuffer = multidimArray!T(nxH, haloSize, nzH);
      sbuffer = arr[0..$, $-2*haloSize-1..$ - haloSize-1, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, M.comm, &mpiStatus);
      arr[0..$, 0..haloSize, 0..$] = rbuffer;
      // Send to negative y
      rbuffer = arr[0..$, 1..1+haloSize, 0..$].dup;
      MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, M.comm, &mpiStatus);
      arr[0..$, $ - haloSize .. $, 0..$] = rbuffer;

      // Send to positive z
      buflen = nxH * nyH;
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

  /**
     Extension for the toString function of the multidimArray, allowing for a fourth dimension.
     It also takes into account verbosity levels and rank formatting.

     Params:
       vl = verbosity level to write at
       logRankFormat = which processes should write
  */
  void show(VL vl, LRF logRankFormat)() {
    immutable uint vdim = dim + ( veclen > 1 );
    static assert( vdim <= 4, "Show vector array not yet implemented for dim + vec > 4.");

    static if ( vdim <= 3 ) {
      writeLog!(vl, logRankFormat)(this.toString());
    }
    else if ( vdim == 4 ) {
      foreach(row; this.byTopDimension) {
        writeLog!(vl, logRankFormat)(row.toString());
      }
    }
  }

}

