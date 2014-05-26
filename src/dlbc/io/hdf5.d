// Written in the D programming language.

/**
   Functions that handle (parallel) IO to disk via HDF5.

   Copyright: Stefan Frijters 2011-2014

   License: $(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License - version 3 (GPL-3.0)).

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
import std.traits;

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
private immutable auto defaultInputFileAName = "input";
private immutable auto defaultMetadataGName = "metadata";
private immutable auto defaultGlobalsGName = "globals";

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
    static if ( is(T : int) ) {
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
*/
void dumpFieldHDF5(T)(ref T field, const string name, const uint time = 0, const bool isCheckpoint = false) {
  herr_t e;

  hsize_t[] dimsg;
  hsize_t[] dimsl;
  hsize_t[] count;
  hsize_t[] stride;
  hsize_t[] block;
  hsize_t[] start;
  hsize_t[] arrstart;

  auto type_id = hdf5Typeof!(T.type);

  auto ndim = field.dimensions;
  assert(ndim == 3, "dumpFieldHDF5 not implemented for ndim != 3");

  auto typeLen = LengthOf!(T.type);

  if ( typeLen > 1 ) {
    ndim++; // One more dimension to store the vector component.
    dimsg = [ gnx, gny, gnz, typeLen ];
    dimsl = [ field.nxH, field.nyH, field.nzH, typeLen ];
    count = [ 1, 1, 1, 1 ];
    stride = [ 1, 1, 1, 1 ];
    block = [ field.nx, field.ny, field.nz, typeLen ];
    start = [ M.cx*field.nx, M.cy*field.ny, M.cz*field.nz, 0 ];
    arrstart = [ field.haloSize, field.haloSize, field.haloSize, 0 ];
  }
  else {
    dimsg = [ gnx, gny, gnz ];
    dimsl = [ field.nxH, field.nyH, field.nzH ];
    count = [ 1, 1, 1 ];
    stride = [ 1, 1, 1 ];
    block = [ field.nx, field.ny, field.nz ];
    start = [ M.cx*field.nx, M.cy*field.ny, M.cz*field.nz ];
    arrstart = [ field.haloSize, field.haloSize, field.haloSize ];
  }

  MPI_Info info = MPI_INFO_NULL;

  string fileNameString;
  if ( isCheckpoint ) {
    fileNameString = makeFilenameCpOutput!(FileFormat.HDF5)(name, time);    
  }
  else {
    fileNameString = makeFilenameOutput!(FileFormat.HDF5)(name, time);
  }
  auto fileName = fileNameString.toStringz();

  writeLogRI("HDF attempting to write to file '%s'.", fileNameString);

  // if (hdf_use_ibm_largeblock_io) then
  //   if (dbg_report_hdf5) call log_msg("HDF using IBM_largeblock_io")
  //   call MPI_Info_create(info, err)
  //   call MPI_Info_set(info, "IBM_largeblock_io", "true", err)
  // end if

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
  e = H5Sselect_hyperslab(filespace, H5S_seloper_t.H5S_SELECT_SET, start.ptr, stride.ptr, count.ptr, block.ptr);
  // In the memspace, we cut off the halo region.
  e = H5Sselect_hyperslab(memspace, H5S_seloper_t.H5S_SELECT_SET, arrstart.ptr, stride.ptr, count.ptr, block.ptr);

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

  // Only root writes the attributes
  if ( M.isRoot() ) {
    file_id = H5Fopen(fileName, H5F_ACC_RDWR, H5P_DEFAULT);

    // Write the input file
    auto root_id = H5Gopen2(file_id, "/", H5P_DEFAULT);
    dumpInputFileAttributes(root_id);
    // Write the metadata
    dumpMetadata(root_id);
    // Write the global state
    if ( isCheckpoint ) {
      dumpCheckpointGlobals(root_id);
    }

    H5Gclose(root_id);
    H5Fclose(file_id);

    // file_id = H5Fopen(fileName, H5F_ACC_RDWR, H5P_DEFAULT);
    // root_id = H5Gopen2(file_id, "/", H5P_DEFAULT);
    // group_id = H5Gopen2(root_id, "globals", H5P_DEFAULT);
    // int bla = readAttributeHDF5!int("time", group_id);
    // auto bla2 = readAttributeHDF5!double("thingie", group_id);
    // H5Gclose(group_id);
    // group_id = H5Gopen2(root_id, "metadata", H5P_DEFAULT);
    // auto bla3 = readAttributeHDF5!string("revisionDesc", group_id);
    // writeLogRD("%s", bla3);
    // H5Gclose(group_id);
    // H5Gclose(root_id);
    // H5Fclose(file_id);
  }
}

void dumpCheckpointGlobals(const hid_t root_id) {
  import dlbc.lb.lb: timestep;
  auto group_id = H5Gcreate2(root_id, "globals", H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
  dumpAttributeHDF5(timestep + 42, "time", group_id);
  H5Gclose(group_id);
}

void readCheckpointGlobals(const hid_t root_id) {
  import dlbc.lb.lb: timestep;
  auto group_id = H5Gopen2(root_id, "globals", H5P_DEFAULT);
  timestep = readAttributeHDF5!int("time", group_id);
  H5Gclose(group_id);
}

void dumpMetadata(const hid_t root_id) {
  import dlbc.revision;
  auto group_id = H5Gcreate2(root_id, "metadata", H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
  dumpAttributeHDF5(revisionHash, "revisionHash", group_id);
  dumpAttributeHDF5(revisionDesc, "revisionDesc", group_id);
  dumpAttributeHDF5(revisionBranch, "revisionBranch", group_id);
  dumpAttributeHDF5(revisionChanged, "revisionChanged", group_id);
  dumpAttributeHDF5(revisionChanges, "revisionChanges", group_id);
  H5Gclose(group_id);
}

/**
   Read a field from disk using HDF5.

   Params:
     field = field to be read
     fileName = name of the file to be read from
*/
void readFieldHDF5(T)(ref T field, const string fileNameString, const bool isCheckpoint = false) {
  herr_t e;

  hsize_t[] dimsg;
  hsize_t[] dimsl;
  hsize_t[] count;
  hsize_t[] stride;
  hsize_t[] block;
  hsize_t[] start;
  hsize_t[] arrstart;

  auto type_id = hdf5Typeof!(T.type);

  auto ndim = field.dimensions;
  assert(ndim == 3, "dumpFieldHDF5 not implemented for ndim != 3");

  auto typeLen = LengthOf!(T.type);

  if ( typeLen > 1 ) {
    ndim++; // One more dimension to store the vector component.
    dimsg = [ gnx, gny, gnz, typeLen ];
    dimsl = [ field.nxH, field.nyH, field.nzH, typeLen ];
    count = [ 1, 1, 1, 1 ];
    stride = [ 1, 1, 1, 1 ];
    block = [ field.nx, field.ny, field.nz, typeLen ];
    start = [ M.cx*field.nx, M.cy*field.ny, M.cz*field.nz, 0 ];
    arrstart = [ field.haloSize, field.haloSize, field.haloSize, 0 ];
  }
  else {
    dimsg = [ gnx, gny, gnz ];
    dimsl = [ field.nxH, field.nyH, field.nzH ];
    count = [ 1, 1, 1 ];
    stride = [ 1, 1, 1 ];
    block = [ field.nx, field.ny, field.nz ];
    start = [ M.cx*field.nx, M.cy*field.ny, M.cz*field.nz ];
    arrstart = [ field.haloSize, field.haloSize, field.haloSize ];
  }

  MPI_Info info = MPI_INFO_NULL;

  auto fileName = fileNameString.toStringz();

  writeLogRI("HDF attempting to read from file '%s'.", fileNameString);

  // if (hdf_use_ibm_largeblock_io) then
  //   if (dbg_report_hdf5) call log_msg("HDF using IBM_largeblock_io")
  //   call MPI_Info_create(info, err)
  //   call MPI_Info_set(info, "IBM_largeblock_io", "true", err)
  // end if

  // Create the file collectively.
  auto fapl_id = H5Pcreate(H5P_FILE_ACCESS);
  H5Pset_fapl_mpio(fapl_id, M.comm, info);
  auto file_id = H5Fopen(fileName, H5F_ACC_RDONLY, fapl_id);
  H5Pclose(fapl_id);

  auto datasetName = defaultDatasetName.toStringz();
  auto dataset_id = H5Dopen2(file_id, datasetName, H5P_DEFAULT);

  auto filespace = H5Dget_space(dataset_id);

  // In the filespace, we have an offset to make sure we write in the correct chunk.
  e = H5Sselect_hyperslab(filespace, H5S_seloper_t.H5S_SELECT_SET, start.ptr, stride.ptr, count.ptr, block.ptr);
  // In the memspace, we cut off the halo region.
  auto memspace = H5Screate_simple(ndim, dimsl.ptr, null);
  e = H5Sselect_hyperslab(memspace, H5S_seloper_t.H5S_SELECT_SET, arrstart.ptr, stride.ptr, count.ptr, block.ptr);

  // Set up for collective IO.
  auto dxpl_id = H5Pcreate(H5P_DATASET_XFER);
  e = H5Pset_dxpl_mpio(dxpl_id, H5FD_mpio_xfer_t.H5FD_MPIO_COLLECTIVE);

  H5Dread(dataset_id, type_id, memspace, filespace, dxpl_id, field.arr._data.ptr);

  // Close all remaining handles.
  H5Sclose(filespace);
  H5Sclose(memspace);
  H5Dclose(dataset_id);
  H5Pclose(dxpl_id);
  H5Fclose(file_id);

  // Only root reads the attributes
  if ( M.isRoot() ) {
    file_id = H5Fopen(fileName, H5F_ACC_RDONLY, H5P_DEFAULT);
    auto root_id = H5Gopen2(file_id, "/", H5P_DEFAULT);
    if ( isCheckpoint ) {
      readCheckpointGlobals(root_id);
    }
    H5Gclose(root_id);
    H5Fclose(file_id);
  }
}

/**
   Dump a single piece of data as an attribute to an HDF5 file.

   Params:
     data = data to write
     name = name of the attribute
     loc_id = id of the location to attach to
*/
void dumpAttributeHDF5(T)(const T data, const string name, hid_t loc_id) {
  auto attrname = name.toStringz();
  hid_t sid, aid, type;
  static if ( is (T == string ) ) {
    hsize_t length[] = [ 1 ];
    auto attrdata = data.toStringz();
    type = H5Tcopy (H5T_C_S1);
    H5Tset_size (type, H5T_VARIABLE);
    sid = H5Screate_simple(1, length.ptr, null);
    aid = H5Acreate2(loc_id, attrname, type, sid, H5P_DEFAULT, H5P_DEFAULT);
    H5Awrite(aid, type, &attrdata);
    H5Tclose(type);
  }
  else {
    hsize_t length[] = [ 1 ];
    sid = H5Screate_simple(1, length.ptr, null);
    aid = H5Acreate2(loc_id, attrname, hdf5Typeof!T, sid, H5P_DEFAULT, H5P_DEFAULT);
    H5Awrite(aid, hdf5Typeof!T, &data);
  }
  H5Aclose(aid);
  H5Sclose(sid);
}

/**
   Read a single piece of data from an attribute of an HDF5 file.

   Params:
     name = name of the attribute
     loc_id = id of the group
*/
T readAttributeHDF5(T)(const string name, hid_t loc_id) {
  import std.conv: to;

  auto attrname = name.toStringz();
  hid_t sid, aid;
  static if ( is (T == string ) ) {
    auto type = H5Tcopy (H5T_C_S1);
    H5Tset_size (type, H5T_VARIABLE);
    auto att = H5Aopen_by_name(loc_id, ".", attrname, H5P_DEFAULT, H5P_DEFAULT);
    auto ftype = H5Aget_type(att);
    auto type_class = H5Tget_class (ftype);
    auto dataspace = H5Aget_space(att);

    hsize_t[] dims;
    dims.length = 1;
    H5Sget_simple_extent_dims(dataspace, dims.ptr, null);
 
    char*[] chars;
    chars.length = dims[0];
    type = H5Tget_native_type(ftype, H5T_direction_t.H5T_DIR_ASCEND);
    H5Aread(att, type, chars.ptr);

    H5Sclose(dataspace);
    H5Tclose(ftype);
    H5Aclose(att);
    H5Tclose(type);
    return to!string(chars[0]);
  }
  else {
    hsize_t length[] = [ 1 ];
    T result;
    sid = H5Screate_simple(1, length.ptr, null);
    aid = H5Aopen_by_name(loc_id, ".", attrname, H5P_DEFAULT, H5P_DEFAULT);
    H5Aread(aid, hdf5Typeof!T, &result);
    H5Aclose(aid);
    H5Sclose(sid);
    return result;
  }
}

/**
   Dump the contents of the input file as an attribute.

   Params:
     loc_id = id of the locataion to attach to
*/
void dumpInputFileAttributes(hid_t loc_id) {
  import dlbc.parameters: inputFileData;
  hid_t sid, aid, type;
  auto attrname = defaultInputFileAName.toStringz();
  hsize_t length[] = [ inputFileData.length ];

  immutable(char)*[] stringz;
  stringz.length = inputFileData.length;
  foreach(i, e; inputFileData) {
    stringz[i] = e.toStringz();
  }
  type = H5Tcopy(H5T_C_S1);
  H5Tset_size(type, H5T_VARIABLE);
  sid = H5Screate_simple(1, length.ptr, null);
  aid = H5Acreate2(loc_id, attrname, type, sid, H5P_DEFAULT, H5P_DEFAULT);
  H5Awrite(aid, type, stringz.ptr);
  H5Tclose(type);
  H5Aclose(aid);
  H5Sclose(sid);
}

/**
   Read the contents of the input file attribute into strings.

   Params:
     fileNameString = name of the file to read from

   Returns: array of strings corresponding to lines of the input file.
*/
string[] readInputFileAttributes(const string fileNameString) {
  import dlbc.parameters: inputFileData;
  import std.conv;

  herr_t ret;
  auto attrname = defaultInputFileAName.toStringz();
  auto fileName = fileNameString.toStringz();
  auto dsetName = defaultDatasetName.toStringz();

  auto file = H5Fopen(fileName, H5F_ACC_RDONLY, H5P_DEFAULT);
  auto type = H5Tcopy (H5T_C_S1);
  ret = H5Tset_size (type, H5T_VARIABLE);
  auto root = H5Gopen2(file, "/", H5P_DEFAULT);
  auto att = H5Aopen_by_name(root, ".", attrname, H5P_DEFAULT, H5P_DEFAULT);
  auto ftype = H5Aget_type(att);
  auto type_class = H5Tget_class (ftype);
  auto dataspace = H5Aget_space(att);

  hsize_t[] dims;
  dims.length = 1;
  H5Sget_simple_extent_dims(dataspace, dims.ptr, null);
 
  char*[] chars;
  chars.length = dims[0];
  type = H5Tget_native_type(ftype, H5T_direction_t.H5T_DIR_ASCEND);
  H5Aread(att, type, chars.ptr);

  H5Sclose(dataspace);
  H5Tclose(ftype);
  H5Aclose(att);
  H5Gclose(root);
  H5Tclose(type);
  H5Fclose(file);

  string[] strings;
  foreach(e; chars) {
    strings ~= to!string(e);
  }

  return strings;
}

