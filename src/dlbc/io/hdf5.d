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

bool hdf5HasStarted = false;

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

