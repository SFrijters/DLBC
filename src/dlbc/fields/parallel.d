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

import unstd.multidimarray;

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
void exchangeHalo(T)(ref T field, uint haloSize) {
  assert( haloSize <= field.haloSize, "Requested size of halo exchange cannot be larger than halo size of field.");

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
  buflen = (field.ny + 2*haloSize) * (field.nz + 2*haloSize) * haloSize * mpiLength;
  field.rbuffer = multidimArray!(T.type)([haloSize, (field.ny + 2*haloSize), (field.nz + 2*haloSize)]);
  field.sbuffer = field.arr[$-lus .. $-uus, haloOffset..$-haloOffset, haloOffset..$-haloOffset].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, M.comm, &mpiStatus);
  field.arr[llr..ulr, haloOffset..$-haloOffset, haloOffset..$-haloOffset] = field.rbuffer;
  // Send to negative x
  field.sbuffer = field.arr[lls..uls, haloOffset..$-haloOffset, haloOffset..$-haloOffset].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nbx[0], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nbx[1], 0, M.comm, &mpiStatus);
  field.arr[$-lur .. $-uur, haloOffset..$-haloOffset, haloOffset..$-haloOffset] = field.rbuffer;

  // Send to positive y
  buflen = (field.nx + 2*haloSize) * (field.nz + 2*haloSize) * haloSize * mpiLength;
  field.rbuffer = multidimArray!(T.type)((field.nx + 2*haloSize), haloSize, (field.nz + 2*haloSize));
  field.sbuffer = field.arr[haloOffset..$-haloOffset, $-lus..$-uus, haloOffset..$-haloOffset].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, M.comm, &mpiStatus);
  field.arr[haloOffset..$-haloOffset, llr..ulr, haloOffset..$-haloOffset] = field.rbuffer;
  // Send to negative y
  field.sbuffer = field.arr[haloOffset..$-haloOffset, lls..uls, haloOffset..$-haloOffset].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nby[0], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nby[1], 0, M.comm, &mpiStatus);
  field.arr[haloOffset..$-haloOffset, $-lur..$-uur, haloOffset..$-haloOffset] = field.rbuffer;

  // Send to positive z
  buflen = (field.nx + 2*haloSize) * (field.ny + 2*haloSize) * haloSize * mpiLength;
  field.rbuffer = multidimArray!(T.type)((field.nx + 2*haloSize), (field.ny + 2*haloSize), haloSize);
  field.sbuffer = field.arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, $-lus..$-uus].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nbz[1], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nbz[0], 0, M.comm, &mpiStatus);
  field.arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, llr..ulr] = field.rbuffer;
  // Send to negative z
  field.sbuffer = field.arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, lls..uls].dup;
  MPI_Sendrecv(field.sbuffer._data.ptr, buflen, mpiType, M.nbz[0], 0, field.rbuffer._data.ptr, buflen, mpiType, M.nbz[1], 0, M.comm, &mpiStatus);
  field.arr[haloOffset..$-haloOffset, haloOffset..$-haloOffset, $-lur..$-uur] = field.rbuffer;
}

void exchangeHalo(T)(ref T field) {
  field.exchangeHalo(field.haloSize);
}

