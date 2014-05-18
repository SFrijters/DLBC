module dlbc.hdf5;

/// hdf5.h -> hdf5.d

import dlbc.mpi;
import dlbc.logging;

public import hdf5.hdf5;

// import core.sys.posix.dlfcn;
// import core.stdc.stdio;
// import core.stdc.stdlib;
// import core.runtime;

// private void *lh;

/**
This function wraps a call to $(D H5open()) to start up HDF5 and reports the version of the HDF5 library.

This function should only be called once during a given program run.
*/
void startHDF5() {
  uint majnum, minnum, relnum;
  herr_t e;

  e = H5open();
  if ( e != 0 ) {
    writeLogF("H5open returned non-zero value.");
  }
  // lh = dlopen("libhdf5.so", RTLD_LAZY);
  // lh = Runtime.loadLibrary("libhdf5.so");
  // if (!lh) {
  //   writeLogF("dlopen error: %s.\n", dlerror());
  // }
  // else {
  //   writeLogRN("Dynamically loaded libhdf5.so.");
  // }
  // loadSymbols();

  // auto H5Open = cast(herr_t function()) dlsym(lh, "H5open");
  // char *error = dlerror();
  // if (error) {
  //   writeLogF("dlsym error: %s\n", error);
  // }
  // e = H5open();

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
  // dlclose(lh);
  // writeLogRN("Unloaded libhdf5.so.");
}

// int loadSymbols() {
//   auto H5P_CLS_FILE_ACCESS_g = cast(hid_t) dlsym(lh, "H5P_CLS_FILE_ACCESS_g");
//   char *error = dlerror();
//   if (error) {
//     writeLogF("dlsym error: %s\n", error);
//   }
//   writeLogRN("H5P_CLS_FILE_ACCESS_g is found.");
//   H5P_FILE_ACCESS = H5P_CLS_FILE_ACCESS_g;
//   writeLogRN("%d %s", H5P_FILE_ACCESS, H5P_CLS_FILE_ACCESS_g);

//   auto H5P_CLS_FILE_CREATE_g = cast(hid_t*) dlsym(lh, "H5P_CLS_FILE_CREATE_g");
//   error = dlerror();
//   if (error) {
//     writeLogF("dlsym error: %s\n", error);
//   }
//   writeLogRN("H5P_CLS_FILE_CREATE_g is found.");
//   H5P_FILE_CREATE = *H5P_CLS_FILE_CREATE_g;
//   writeLogRN("%d %d %s", H5P_FILE_CREATE, *H5P_CLS_FILE_CREATE_g, H5P_CLS_FILE_CREATE_g);


//   return 0;
// }

// extern(C):

// hid_t H5Screate_simple(int rank, const hsize_t *dims, const hsize_t *maxdims);
// enum H5S_ALL = 0;

/// H5public.h
// alias int herr_t;
// alias ulong hsize_t;
// alias ulong hssize_t;

// herr_t H5open();
// herr_t H5close();
// herr_t H5dont_atexit();
// herr_t H5garbage_collect();
// herr_t H5set_free_list_limits (int reg_global_lim, int reg_list_lim,
//                 int arr_global_lim, int arr_list_lim, int blk_global_lim,
//                 int blk_list_lim);
// herr_t H5get_libversion(uint *majnum, uint *minnum, uint *relnum);
// herr_t H5check_version(uint majnum, uint minnum, uint relnum);

/// H5Fpublic.h
// hid_t H5Fcreate(const char *filename, uint flags, hid_t create_plist, hid_t access_plist);

// uint H5F_ACC_RDONLY = 0x0000u;	/*absence of rdwr => rd-only */
// uint H5F_ACC_RDWR   = 0x0001u;	/*open for read and write    */
// uint H5F_ACC_TRUNC  = 0x0002u;	/*overwrite existing files   */
// uint H5F_ACC_EXCL   = 0x0004u;	/*fail if file already exists*/
// uint H5F_ACC_DEBUG  = 0x0008u;	/*print debug info	     */
// uint H5F_ACC_CREAT  = 0x0010u;	/*create non-existing files  */

/// H5FDpublic.h
// herr_t H5Pset_fapl_mpio(hid_t fapl_id, MPI_Comm comm, MPI_Info info);
// herr_t H5Pget_fapl_mpio(hid_t fapl_id, MPI_Comm *comm/*out*/,
// 			MPI_Info *info/*out*/);

/// H5Ipublic.h
// alias int hid_t;

/// H5Ppublic.h
// hid_t H5Pcreate(hid_t cls_id);
// herr_t H5Pclose(hid_t plist_id);

// extern __gshared hid_t H5P_FILE_CREATE;

// // __gshared hid_t H5P_CLS_FILE_ACCESS_g;


// /// H5Tpublic.h
// __gshared hid_t H5T_NATIVE_SCHAR_g;
// __gshared hid_t H5T_NATIVE_UCHAR_g;
// __gshared hid_t H5T_NATIVE_SHORT_g;
// __gshared hid_t H5T_NATIVE_USHORT_g;
// extern __gshared hid_t H5T_NATIVE_INT_g;
// __gshared hid_t H5T_NATIVE_UINT_g;
// __gshared hid_t H5T_NATIVE_LONG_g;
// __gshared hid_t H5T_NATIVE_ULONG_g;
// __gshared hid_t H5T_NATIVE_LLONG_g;
// __gshared hid_t H5T_NATIVE_ULLONG_g;
// __gshared hid_t H5T_NATIVE_FLOAT_g;
// extern __gshared hid_t H5T_NATIVE_DOUBLE_g;


// extern __gshared hid_t H5P_LST_FILE_CREATE_g;

// extern(C) extern __gshared hid_t H5P_CLS_FILE_ACCESS_g;
// hid_t H5P_FILE_ACCESS = H5P_CLS_FILE_ACCESS_g;

// hid_t H5Dcreate2(hid_t loc_id, const char *name, hid_t type_id,
//     hid_t space_id, hid_t lcpl_id, hid_t dcpl_id, hid_t dapl_id);

// herr_t H5Dwrite(hid_t dset_id, hid_t mem_type_id, hid_t mem_space_id,
// 			 hid_t file_space_id, hid_t plist_id, const void *buf);

// extern __gshared hid_t H5T_STD_I32BE_g;

// enum H5P_DEFAULT = 0;


