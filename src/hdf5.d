/// hdf5.h -> hdf5.d

extern(C):

alias int herr_t;

herr_t H5open();
herr_t H5close();
herr_t H5dont_atexit();
herr_t H5garbage_collect();
herr_t H5set_free_list_limits (int reg_global_lim, int reg_list_lim,
                int arr_global_lim, int arr_list_lim, int blk_global_lim,
                int blk_list_lim);
herr_t H5get_libversion(uint *majnum, uint *minnum, uint *relnum);
herr_t H5check_version(uint majnum, uint minnum, uint relnum);

