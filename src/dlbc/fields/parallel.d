// Written in the D programming language.

/**
   Parallelization for fields.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

   Authors: Stefan Frijters

   Macros:
        TR = <tr>$0</tr>
        TH = <th>$0</th>
        TD = <td>$0</td>
        TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.fields.parallel;

import dlbc.fields.field;
import dlbc.logging;
import dlbc.parallel;
import dlbc.timers;

import unstd.multidimarray;

/**
   The halo of the field is exchanged with all neighbours. The data is first
   stored in the send buffer $(D field.sbuffer), and data from the neighbours
   is received in $(D field.rbuffer). Because the slicing is performed in an
   identical fashion on all processes, we can then easily put the data in the
   correct spot in the main array. If haloSize is not supplied explicitly,
   the maximum halo size is used. In any event, haloSize cannot be larger than
   $(D field.haloSize).

   Params:
     field = field to exchange the data of
     haloSize = width of the halo to be exchanged; this can be smaller than
                the halo that is held in memory

   Todo: add unittest
*/
void exchangeHalo(T)(ref T field, uint haloSize) if (isField!T) {
  import std.algorithm: all;
  if ( !all(field.lengths[]) ) return;
  static if ( field.dimensions == 3 ) {
    field.exchangeHalo3D(haloSize);
  }
  else static if ( field.dimensions == 2 ) {
    field.exchangeHalo2D(haloSize);
  }
  else {
    static assert(0, "Halo exchange not implemented for dimensions != 3 or 2.");
  }
}

/// Ditto
void exchangeHalo(T)(ref T field) if (isField!T) {
  field.exchangeHalo(field.haloSize);
}

/**
   Halo exchange for three-dimensional fields.
*/
void exchangeHalo3D(T)(ref T field, uint haloSize) if (isField!T) {
  import std.conv: to;

  static assert(field.dimensions == 3);
  assert( haloSize <= field.haloSize, "Requested size of halo exchange cannot be larger than halo size of field.");

  Timers.haloExchange.start();

  writeLogRD("Performing halo exchange of size %d.", haloSize);

  uint buflen;

  /**
     MPI datatype corresponding to type $(D T.type).
  */
  immutable auto mpiType = mpiTypeof!(field.type);
  immutable auto mpiLength = mpiLengthof!(field.type);

  MPI_Status mpiStatus;

  immutable uint haloOffset = field.haloSize - haloSize;

  immutable uint lus = field.haloSize + haloOffset + haloSize;
  immutable uint uus = field.haloSize + haloOffset;
  immutable uint lls = field.haloSize + haloOffset;
  immutable uint uls = field.haloSize + haloOffset + haloSize;

  immutable uint lur = haloOffset + haloSize;
  immutable uint uur = haloOffset;
  immutable uint llr = haloOffset;
  immutable uint ulr = haloOffset + haloSize;

  // Send to positive x
  buflen = to!uint((field.n[1] + 2*haloSize) * (field.n[2] + 2*haloSize) * haloSize * mpiLength);
  field.rbuffer = multidimArray!(T.type)([haloSize, (field.n[1] + 2*haloSize), (field.n[2] + 2*haloSize)]);
  field.sbuffer = field.arr[$-lus .. $-uus, haloOffset..$-haloOffset, haloOffset..$-haloOffset].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nb[0][1], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nb[0][0], 0, M.comm, &mpiStatus);
  field.arr[llr..ulr, haloOffset..$-haloOffset, haloOffset..$-haloOffset] = field.rbuffer;
  // Send to negative x
  field.sbuffer = field.arr[lls..uls, haloOffset..$-haloOffset, haloOffset..$-haloOffset].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nb[0][0], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nb[0][1], 0, M.comm, &mpiStatus);
  field.arr[$-lur .. $-uur, haloOffset..$-haloOffset, haloOffset..$-haloOffset] = field.rbuffer;

  // Send to positive y
  buflen = to!uint((field.n[0] + 2*haloSize) * (field.n[2] + 2*haloSize) * haloSize * mpiLength);
  field.rbuffer = multidimArray!(T.type)((field.n[0] + 2*haloSize), haloSize, (field.n[2] + 2*haloSize));
  field.sbuffer = field.arr[haloOffset..$-haloOffset, $-lus..$-uus, haloOffset..$-haloOffset].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nb[1][1], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nb[1][0], 0, M.comm, &mpiStatus);
  field.arr[haloOffset..$-haloOffset, llr..ulr, haloOffset..$-haloOffset] = field.rbuffer;
  // Send to negative y
  field.sbuffer = field.arr[haloOffset..$-haloOffset, lls..uls, haloOffset..$-haloOffset].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nb[1][0], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nb[1][1], 0, M.comm, &mpiStatus);
  field.arr[haloOffset..$-haloOffset, $-lur..$-uur, haloOffset..$-haloOffset] = field.rbuffer;

  // Send to positive z
  buflen = to!uint((field.n[0] + 2*haloSize) * (field.n[1] + 2*haloSize) * haloSize * mpiLength);
  field.rbuffer = multidimArray!(T.type)((field.n[0] + 2*haloSize), (field.n[1] + 2*haloSize), haloSize);
  field.sbuffer = field.arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, $-lus..$-uus].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nb[2][1], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nb[2][0], 0, M.comm, &mpiStatus);
  field.arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, llr..ulr] = field.rbuffer;
  // Send to negative z
  field.sbuffer = field.arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, lls..uls].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nb[2][0], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nb[2][1], 0, M.comm, &mpiStatus);
  field.arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, $-lur..$-uur] = field.rbuffer;

  Timers.haloExchange.stop();
}

/**
   Halo exchange for two-dimensional fields.
*/
void exchangeHalo2D(T)(ref T field, uint haloSize) if (isField!T) {
  import std.conv: to;

  static assert(field.dimensions == 2);
  assert( haloSize <= field.haloSize, "Requested size of halo exchange cannot be larger than halo size of field.");

  Timers.haloExchange.start();

  writeLogRD("Performing halo exchange of size %d.", haloSize);

  uint buflen;

  /**
     MPI datatype corresponding to type $(D T.type).
  */
  immutable auto mpiType = mpiTypeof!(field.type);
  immutable auto mpiLength = mpiLengthof!(field.type);

  MPI_Status mpiStatus;

  immutable uint haloOffset = field.haloSize - haloSize;

  immutable uint lus = field.haloSize + haloOffset + haloSize;
  immutable uint uus = field.haloSize + haloOffset;
  immutable uint lls = field.haloSize + haloOffset;
  immutable uint uls = field.haloSize + haloOffset + haloSize;

  immutable uint lur = haloOffset + haloSize;
  immutable uint uur = haloOffset;
  immutable uint llr = haloOffset;
  immutable uint ulr = haloOffset + haloSize;

  // Send to positive x
  buflen = to!uint((field.n[1] + 2*haloSize) * haloSize * mpiLength);
  field.rbuffer = multidimArray!(T.type)([haloSize, (field.n[1] + 2*haloSize)]);
  field.sbuffer = field.arr[$-lus .. $-uus, haloOffset..$-haloOffset].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nb[0][1], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nb[0][0], 0, M.comm, &mpiStatus);
  field.arr[llr..ulr, haloOffset..$-haloOffset] = field.rbuffer;
  // Send to negative x
  field.sbuffer = field.arr[lls..uls, haloOffset..$-haloOffset].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nb[0][0], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nb[0][1], 0, M.comm, &mpiStatus);
  field.arr[$-lur .. $-uur, haloOffset..$-haloOffset] = field.rbuffer;

  // Send to positive y
  buflen = to!uint((field.n[0] + 2*haloSize) * haloSize * mpiLength);
  field.rbuffer = multidimArray!(T.type)((field.n[0] + 2*haloSize), haloSize);
  field.sbuffer = field.arr[haloOffset..$-haloOffset, $-lus..$-uus].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nb[1][1], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nb[1][0], 0, M.comm, &mpiStatus);
  field.arr[haloOffset..$-haloOffset, llr..ulr] = field.rbuffer;
  // Send to negative y
  field.sbuffer = field.arr[haloOffset..$-haloOffset, lls..uls].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nb[1][0], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nb[1][1], 0, M.comm, &mpiStatus);
  field.arr[haloOffset..$-haloOffset, $-lur..$-uur] = field.rbuffer;

  Timers.haloExchange.stop();
}

