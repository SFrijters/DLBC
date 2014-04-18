// Written in the D programming language.

/**
Functions that handle (parallel) output to disk.

Copyright: Stefan Frijters 2011-2014

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Stefan Frijters

Macros:
	TR = <tr>$0</tr>
	TH = <th>$0</th>
	TD = <td>$0</td>
	TABLE = <table border=1 cellpadding=4 cellspacing=0>$0</table>
*/

module io;

import hdf5;
import logging;

/**
This function wraps a call to $(D H5open()) to start up HDF5 and reports the version of the HDF5 library.

This function should only be called once during a given program run.
*/
void startHDF5() {
  uint majnum, minnum, relnum;
  herr_t e;
  e = H5open();
  e = H5get_libversion(&majnum, &minnum, &relnum);
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

