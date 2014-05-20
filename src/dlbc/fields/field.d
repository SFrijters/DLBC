// Written in the D programming language.

/**
   Implementation of scalar and vector fields on the lattice.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.fields.field;

import dlbc.logging;
import dlbc.parallel;

import unstd.multidimarray;
import unstd.generictuple;

/**
   The $(D Field) struct is designed as a template to hold scalars or vectors of
   arbitrary type on a lattice of arbitrary dimension (this will normally match
   the dimensionality of the underlying $(D Lattice) struct).

   Params:
     T = datatype to be held
     dim = dimensionality of the field
     hs = size of the halo region
*/
struct Field(T, uint dim, uint hs) {
  static assert(dim > 1, "1D fields are not supported.");
  static assert(dim == 3, "Non-3D fields not yet implemented.");

  MultidimArray!(T, dim) arr, sbuffer, rbuffer;

  enum uint dimensions = dim;
  enum uint haloSize = hs;
  private uint[dim] _lengths;
  private uint[dim] _lengthsH;

  alias T type;

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
     Allows to access the underlying multidimensional array correctly.
  */
  alias arr this;

  /**
     A $(D Field) is constructed by specifying the size of the physical domain and the required halo size.

     Params:
       lengths = lengths of the dimensions of the physical domain
  */
  this (const uint[dim] lengths) {
    writeLogRD("Initializing %s local field of type '%s' with halo of thickness %d.", lengths.makeLengthsString, T.stringof, haloSize);

    this._lengths = lengths;
    // Why doesn't scalar addition work?
    this._lengthsH[0] = lengths[0] + (2* hs);
    this._lengthsH[1] = lengths[1] + (2* hs);
    this._lengthsH[2] = lengths[2] + (2* hs);

    arr = multidimArray!T(nxH, nyH, nzH);
  }

  /**
     This variant of opApply loops over the physical part of the lattice only
     and overloads the opApply of the underlying multidimArray.
     If the foreach loop is supplied with a reference to the array directly
     it will loop over all lattice sites instead (including the halo).

     Example:
     ----
     foreach(x, y, z, ref el; sfield) {
       // Loops over physical sites of scalar field only.
     }

     foreach(x, y, z, ref el; sfield.arr) {
       // Loops over all lattice sites of scalar field.
     }
     ---

     Todo: add unittest
  */
  int opApply(int delegate(RepeatTuple!(arr.dimensions, size_t), ref T) dg) {
    if(!elements)
      return 0;

    RepeatTuple!(arr.dimensions, size_t) indices = haloSize;
    indices[$ - 1] = -1 + haloSize;

    for(;;) {
      foreach_reverse(const plane, ref index; indices) {
	if(++index < arr.lengths[plane] - haloSize)
	  break;
	else if(plane)
	  index = haloSize;
	else
	  return 0;
      }

      if(const res = dg(indices, arr._data[getOffset(indices)]))
	return res;
    }
  }

  /**
     The halo of the field is exchanged with all 6 neighbours, according to 
     the haloSize specified when the field was created. The data is first
     stored in the send buffer $(D sbuffer), and data from the neighbours is
     received in $(D rbuffer). Because the slicing is performed in an
     identical fashion on all processes, we can easily put the data in the
     correct spot in the main array.

     Params:
       haloSize = width of the halo to be exchanged; this can be smaller than
                  the halo that is held in memory

     Todo: add unittest

     Bugs: when compiling in -release mode, the buffers are somehow not
     allocated properly, or optimized away.
     ---
     Fatal error in MPI_Sendrecv: Invalid buffer pointer, error stack:
     MPI_Sendrecv(215): MPI_Sendrecv(sbuf=(nil), scount=27360, MPI_DOUBLE, dest=5, stag=0, rbuf=(nil), rcount=27360, MPI_DOUBLE, src=5, rtag=0, comm=0x84000002, status=0x7fff71bb1410) failed
     MPI_Sendrecv(149): Null buffer pointer
     ---
  */
  void exchangeHalo(uint haloSize = hs)() {
    static assert( haloSize <= hs, "Requested size of halo exchange cannot be larger than halo size of field.");

    writeLogRD("Performing halo exchange of size %d.", haloSize);

    uint buflen;

    /**
       MPI datatype corresponding to type $(D T).
    */
    auto mpiType = mpiTypeof!type;
    auto mpiLength = mpiLengthof!type;

    MPI_Status mpiStatus;

    uint haloOffset = this.haloSize - haloSize;

    uint lus = this.haloSize + haloOffset + haloSize;
    uint uus = this.haloSize + haloOffset;
    uint lls = this.haloSize + haloOffset;
    uint uls = this.haloSize + haloOffset + haloSize;

    uint lur = haloOffset + haloSize;
    uint uur = haloOffset;
    uint llr = haloOffset;
    uint ulr = haloOffset + haloSize;

    // Send to positive x
    buflen = (ny + 2*haloSize) * (nz + 2*haloSize) * haloSize * mpiLength;
    rbuffer = multidimArray!T(haloSize, (ny + 2*haloSize), (nz + 2*haloSize));
    sbuffer = arr[$-lus .. $-uus, haloOffset..$-haloOffset, haloOffset..$-haloOffset].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, M.comm, &mpiStatus);
    arr[llr..ulr, haloOffset..$-haloOffset, haloOffset..$-haloOffset] = rbuffer;
    // Send to negative x
    sbuffer = arr[lls..uls, haloOffset..$-haloOffset, haloOffset..$-haloOffset].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, M.comm, &mpiStatus);
    arr[$-lur .. $-uur, haloOffset..$-haloOffset, haloOffset..$-haloOffset] = rbuffer;

    // Send to positive y
    buflen = (nx + 2*haloSize) * (nz + 2*haloSize) * haloSize * mpiLength;
    rbuffer = multidimArray!T((nx + 2*haloSize), haloSize, (nz + 2*haloSize));
    sbuffer = arr[haloOffset..$-haloOffset, $-lus..$-uus, haloOffset..$-haloOffset].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, M.comm, &mpiStatus);
    arr[haloOffset..$-haloOffset, llr..ulr, haloOffset..$-haloOffset] = rbuffer;
    // Send to negative y
    sbuffer = arr[haloOffset..$-haloOffset, lls..uls, haloOffset..$-haloOffset].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, M.comm, &mpiStatus);
    arr[haloOffset..$-haloOffset, $-lur..$-uur, haloOffset..$-haloOffset] = rbuffer;

    // Send to positive z
    buflen = (nx + 2*haloSize) * (ny + 2*haloSize) * haloSize * mpiLength;
    rbuffer = multidimArray!T((nx + 2*haloSize), (ny + 2*haloSize), haloSize);
    sbuffer = arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, $-lus..$-uus].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbz[1], 0, rbuffer._data.ptr, buflen, mpiType, M.nbz[0], 0, M.comm, &mpiStatus);
    arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, llr..ulr] = rbuffer;
    // Send to negative z
    sbuffer = arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, lls..uls].dup;
    MPI_Sendrecv(sbuffer._data.ptr, buflen, mpiType, M.nbz[0], 0, rbuffer._data.ptr, buflen, mpiType, M.nbz[1], 0, M.comm, &mpiStatus);
    arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, $-lur..$-uur] = rbuffer;
  }

  /**
     Extension for the toString function of the multidimArray, allowing for a fourth dimension.
     It also takes into account verbosity levels and rank formatting.

     Params:
       vl = verbosity level to write at
       logRankFormat = which processes should write
  */
  void show(VL vl, LRF logRankFormat)() {
    writeLog!(vl, logRankFormat)(this.toString());
  }
}


