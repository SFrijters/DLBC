// Written in the D programming language.

/**
Functions that handle (parallel) IO to disk via HDF5.

Copyright: Stefan Frijters 2011-2014

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module dlbc.io.hdf5;

import dlbc.mpi;
import dlbc.logging;

public import hdf5.hdf5;

private bool hdf5HasStarted = false;

/**
   This function wraps a call to $(D H5open()) to start up HDF5 and reports the version of the HDF5 library.

   This function should only be called once during a given program run.
*/
void startHDF5() {
  if (hdf5HasStarted ) {
    return;
  }

  uint majnum, minnum, relnum;
  herr_t e;

  e = H5open();
  if ( e != 0 ) {
    writeLogF("H5open returned non-zero value.");
  }

  H5get_libversion(&majnum, &minnum, &relnum);
  H5check_version(majnum, minnum, relnum);
  writeLogRN("Opened HDF5 v%d.%d.%d.", majnum, minnum, relnum);
}

/**
   This function wraps a call to $(D H5close()) to gracefully shut down HDF5.

   This function should only be called once during a given program run.
*/
void endHDF5() {
  herr_t e;
  e = H5close();
  writeLogRN("Closed HDF5.");
}

/**
   This template function returns an HDF5 data type identifier based on the type T.
   If T is an array, the base type is returned.

   Params:
     T = a type

   Returns: the corresponding HDF5 data type identifier
*/
hid_t hdf5Typeof(T)() {
  import dlbc.range;
  import std.traits;
  static if ( isArray!T ) {
    return mpiTypeof!(BaseElementType!T);
  }
  else {
    static if ( is(T == int) ) {
      return H5T_NATIVE_INT;
    }
    else static if ( is(T == double) ) {
      return H5T_NATIVE_DOUBLE;
    }
    else {
      static assert(0, "Datatype not implemented for HDF5.");
    }
  }
}

/**
   This template function returns the length of a static array of type T or 1 if
   the type is not an array.

   Params:
     T = a type

   Returns: the corresponding length
*/
size_t hdf5Lengthof(T)() {
  import dlbc.range;
  return LengthOf!T;
}

