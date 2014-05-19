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

public import hdf5.hdf5;

import std.string: toStringz;

import dlbc.io.io;
import dlbc.lattice: gnx, gny, gnz;
import dlbc.logging;
import dlbc.parallel;
import dlbc.range;

/**
   Use chunked HDF5. This is normally not recommended.
*/
@("param") bool writeChunked = false;

private bool hdf5HasStarted = false;

private immutable auto defaultDatasetName = "/OutArray";

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
    return hdf5Typeof!(BaseElementType!T);
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

/**
   Write a field to disk using HDF5.

   Params:
     field = field to be written
     name = name of the field, to be used in the file name

   Todo: Add support for vector fields.
   Todo: Add support for attributes.
*/
void dumpFieldHDF5(T)(T field, const string name) {

  immutable auto type_id = hdf5Typeof!(T.type);
  immutable auto ndim = field.dimensions;
  assert(ndim == 3, "dumpFieldHDF5 not implemented for ndim != 3");

  herr_t e;
  MPI_Info info = MPI_INFO_NULL;

  auto fileNameString = makeFilenameOutput!(FileFormat.HDF5)(name);
  auto fileName = fileNameString.toStringz();

  writeLogRI("HDF attempting to write to file '%s'.", fileNameString);

  // if (hdf_use_ibm_largeblock_io) then
  //   if (dbg_report_hdf5) call log_msg("HDF using IBM_largeblock_io")
  //   call MPI_Info_create(info, err)
  //   call MPI_Info_set(info, "IBM_largeblock_io", "true", err)
  // end if

  hsize_t[] dimsg = [ gnx, gny, gnz ];
  hsize_t[] dimsl = [ field.nxH, field.nyH, field.nzH ];
  hsize_t[] count = [ 1, 1, 1 ];
  hsize_t[] stride = [ 1, 1, 1 ];
  hsize_t[] block = [ field.nx, field.ny, field.nz ];
  hsize_t[] start = [ M.cx*field.nx, M.cy*field.ny, M.cz*field.nz ];
  hsize_t[] arrstart = [ field.haloSize, field.haloSize, field.haloSize ];

  // Create the file collectively.
  auto fapl_id = H5Pcreate(H5P_FILE_ACCESS);
  H5Pset_fapl_mpio(fapl_id, M.comm, info);
  auto file_id = H5Fcreate(fileName, H5F_ACC_TRUNC, H5P_DEFAULT, fapl_id);
  H5Pclose(fapl_id);

  // Create the data spaces for the dataset, using global and local size
  // (including halo!), respectively.
  auto filespace = H5Screate_simple(ndim, dimsg.ptr, null);
  auto memspace = H5Screate_simple(ndim, dimsl.ptr, null);

  hid_t dcpl_id;
  if ( writeChunked ) {
    dcpl_id = H5Pcreate(H5P_DATASET_CREATE);
    H5Pset_chunk(dcpl_id, ndim, block.ptr);
  }
  else {
    dcpl_id = H5P_DEFAULT;
  }

  auto datasetName = defaultDatasetName.toStringz();
  auto dataset_id = H5Dcreate2(file_id, datasetName, type_id, filespace, H5P_DEFAULT, dcpl_id, H5P_DEFAULT);
  H5Sclose(filespace);
  H5Pclose(dcpl_id);

  filespace = H5Dget_space(dataset_id);
  // In the filespace, we have an offset to make sure we write in the correct chunk.
  auto status = H5Sselect_hyperslab(filespace, H5S_seloper_t.H5S_SELECT_SET, start.ptr, stride.ptr, count.ptr, block.ptr);
  // In the memspace, we cut off the halo region.
  status = H5Sselect_hyperslab(memspace, H5S_seloper_t.H5S_SELECT_SET, arrstart.ptr, stride.ptr, count.ptr, block.ptr);

  // Set up for collective IO.
  auto dxpl_id = H5Pcreate(H5P_DATASET_XFER);
  e = H5Pset_dxpl_mpio(dxpl_id, H5FD_mpio_xfer_t.H5FD_MPIO_COLLECTIVE);

  H5Dwrite(dataset_id, type_id, memspace, filespace, dxpl_id, field.arr._data.ptr);

  // Close all remaining handles.
  H5Sclose(filespace);
  H5Sclose(memspace);
  H5Dclose(dataset_id);
  H5Pclose(dxpl_id);
  H5Fclose(file_id);

  // ! Call subroutine which adds the metadata, now the raw dataset exists
  // ! Only possible from one processor
  // if (myrankc .eq. 0 ) then
  //   if (dbg_report_hdf5) call log_msg("HDF writing metadata")
  //   call lbe_write_attr_phdf5(filename, dsetname, attrname)
  //   if (dbg_report_hdf5) call log_msg("HDF finished writing metadata")
  // end if
}

