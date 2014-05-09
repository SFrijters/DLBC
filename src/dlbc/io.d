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

module dlbc.io;

import dlbc.hdf5;
import dlbc.lattice;
import dlbc.logging;

void dumpFieldHDF5(T)(const Field!T f, const string name) {

  // character(len=*), intent(in) :: name
  // character(len=1024) :: filename
  // character(len=1024) :: attrname

  // character(len=8), parameter :: dsetname = 'OutArray' !Dataset name

  hid_t file_id;   // File identifier
  hid_t dset_id;   // Dataset identifier
  hid_t filespace; // Dataspace identifier in file
  hid_t memspace;  // Dataspace identifier in memory
  hid_t plist_id;  // Property list identifier
  hid_t type_id = hdf5Typeof!T;   // Datatype id for array (real or double)

  herr_t e;

  // integer(hssize_t), dimension(3) :: offset
  // ! integer(hsize_t),  dimension(3) :: chunk_dims

  // integer, parameter :: ndim = 3 ! Dataset rank

  // integer :: err ! Error flags
  MPI_Info info;
  // integer :: comm ! for MPI


  // call lbe_make_filename_output(filename, trim(name), '.h5', nt)
  // attrname = filename ! attrname has to be unique, can't have it twice

  writeLogRI("HDF attempting to write to file '%s'.", name);

  // info = MPI_INFO_NULL

  // if (hdf_use_ibm_largeblock_io) then
  //   if (dbg_report_hdf5) call log_msg("HDF using IBM_largeblock_io")
  //   call MPI_Info_create(info, err)
  //   call MPI_Info_set(info, "IBM_largeblock_io", "true", err)
  // end if

  hsize_t[3] dimsg = [ gnx, gny, gnz ];

  // dimsf  = (/tnx, tny, tnz/)
  hsize_t[3] dimsl = [ f.nx, f.ny, f.nz ];
  // dims   = (/nx, ny, nz/)
  hsize_t[3] count = [ f.nx, f.ny, f.nz ];
  // count  = (/nx, ny, nz/)
  //! chunk_dims = (/nx, ny, nz/);

  // ! Note: the above is in fact equivalent to the count/stride/block formulation:
  // ! count  = (/1, 1, 1/)
  // ! stride = (/1, 1, 1/)
  // ! block  = (/nx, ny, nz/)
  // ! (with matching parameters in h5sselect_hyperslab_f

  hssize_t[3] offset = [ M.cx*f.nx, M.cy*f.ny, M.cz*f.nz ];

  // offset(1) = ccoords(1)*nx
  // offset(2) = ccoords(2)*ny
  // offset(3) = ccoords(3)*nz
  // plist_id = H5Pcreate(150994952);
  // plist_id = H5Pcreate(H5P_FILE_ACCESS);
  // import std.stdio;
  // writeLogD("%d %d", H5P_FILE_ACCESS, plist_id);
  // return;
  // e = H5Pset_fapl_mpio(plist_id, M.comm, info);
  // Create the file collectively.
  writeLogD("%d", H5F_ACC_TRUNC);
  // return;
  if ( M.isRoot ) {
    e = H5Fcreate("test.h5", H5F_ACC_TRUNC, file_id, plist_id);
    e = H5Pclose(plist_id);
  }

  

//   ! Setup file access property list with parallel I/O access.
//   if (dbg_report_hdf5) call log_msg("HDF creating file")
//   call h5pcreate_f(H5P_FILE_ACCESS_F, plist_id, err)
//   call h5pset_fapl_mpio_f(plist_id, Comm_cart, info, err)
//   ! Create the file collectively.
//   call h5fcreate_f(filename, H5F_ACC_TRUNC_F, file_id, err, access_prp = plist_id)
//   if (dbg_report_hdf5) call log_msg("HDF closing property list handle")
//   call h5pclose_f(plist_id, err)

//   ! Create the data space for the dataset.
//   if (dbg_report_hdf5) call log_msg("HDF creating filespace")
//   call h5screate_simple_f(ndim, dimsf, filespace, err)

//   ! Create chunked dataset.
//   ! This should hopefully be needed nevermore
//   ! if (dbg_report_hdf5) call log_msg("HDF creating chunked dataset")
//   ! call h5pcreate_f(H5P_DATASET_CREATE_F, plist_id, err)
//   ! call h5pset_chunk_f(plist_id, ndim, chunk_dims, err)
//   ! call h5dcreate_f(file_id, dsetname, type_id, filespace, dset_id, err, plist_id)
//   ! call h5pclose_f(plist_id, err)

//   ! Create continuous dataset.
//   if (dbg_report_hdf5) call log_msg("HDF creating continuous dataset")
//   call h5dcreate_f(file_id, dsetname, type_id, filespace, dset_id, err)

//   call h5sclose_f(filespace, err)

//   ! Each process defines dataset in memory and writes it to the hyperslab in the file.
//   if (dbg_report_hdf5) call log_msg("HDF creating memspace")
//   call h5screate_simple_f(ndim, dims, memspace, err)

//   ! Select hyperslab in the file.
//   if (dbg_report_hdf5) call log_msg("HDF selecting hyperslab")
//   call h5dget_space_f(dset_id, filespace, err)
//   call h5sselect_hyperslab_f (filespace, H5S_SELECT_SET_F, offset, count, err)

//   ! Create property list for collective dataset write
//   call h5pcreate_f(H5P_DATASET_XFER_F, plist_id, err)
//   if (hdf_use_independent_io) then
//     if (dbg_report_hdf5) call log_msg("HDF using H5FD_MPIO_INDEPENDENT_F")
//     call h5pset_dxpl_mpio_f(plist_id, H5FD_MPIO_INDEPENDENT_F, err)
//   else
//     if (dbg_report_hdf5) call log_msg("HDF using H5FD_MPIO_COLLECTIVE_F")
//     call h5pset_dxpl_mpio_f(plist_id, H5FD_MPIO_COLLECTIVE_F, err)
//   end if

//   if (dbg_report_hdf5_timing) then
//     t_init_f = MPI_Wtime()
//     call MPI_Barrier(Comm_cart,err)
//     t_write_s = MPI_Wtime()
//   end if

//   ! Different write calls for double or single data (have to convert real*8 scalar to real*4)
//   if (dump_double) then
//     if (dbg_report_hdf5) call log_msg("HDF writing double data")
//     call h5dwrite_f(dset_id, type_id, scalar, dims, err, file_space_id = filespace, mem_space_id = memspace, xfer_prp = plist_id)
//   else
//     if (dbg_report_hdf5) call log_msg("HDF writing single data")
//     call h5dwrite_f(dset_id, type_id, real(scalar,4), dims, err, file_space_id = filespace, mem_space_id = memspace, xfer_prp = plist_id)
//   end if

//   if (dbg_report_hdf5_timing) then
//     t_write_f = MPI_Wtime()
//     call MPI_Barrier(Comm_cart,err)
//     t_close_s = MPI_Wtime()
//   end if

//   ! Close dataspaces.
//   if (dbg_report_hdf5) call log_msg("HDF closing filespace handle")
//   call h5sclose_f(filespace, err)
//   if (dbg_report_hdf5) call log_msg("HDF closing memspace handle")
//   call h5sclose_f(memspace, err)
//   ! Close the dataset.
//   if (dbg_report_hdf5) call log_msg("HDF closing dataset handle")
//   call h5dclose_f(dset_id, err)
//   ! Close the property list.
//   if (dbg_report_hdf5) call log_msg("HDF closing property list handle")
//   call h5pclose_f(plist_id, err)

//   if (dbg_report_hdf5_timing) then
//     t_close_f = MPI_Wtime()
//     call MPI_Barrier(Comm_cart,err)
//     t_closef_s = MPI_Wtime()
//   end if

//   ! Close the file.
//   if (dbg_report_hdf5) call log_msg("HDF closing file handle")
//   call h5fclose_f(file_id, err)
//   if (dbg_report_hdf5) call log_msg("HDF finished closing handles")

//   if (dbg_report_hdf5_timing) then
//     t_closef_f = MPI_Wtime()
//   end if

//   ! Call subroutine which adds the metadata, now the raw dataset exists
//   ! Only possible from one processor
//   if (myrankc .eq. 0 ) then
//     if (dbg_report_hdf5) call log_msg("HDF writing metadata")
//     call lbe_write_attr_phdf5(filename, dsetname, attrname)
//     if (dbg_report_hdf5) call log_msg("HDF finished writing metadata")
//   end if

//   if (dbg_report_hdf5) call log_msg_hdr("HDF scalar real write debug finished")

//   if (dbg_report_hdf5_timing) then
//     ! This is a lot of debugging/timing stuff
//     ! All processors create a string with their timings, then send it to rank 0.
//     ! Rank 0 can then display them all in correct order
//     call MPI_Barrier(Comm_cart,err)
//     t_f = MPI_Wtime()

//     call log_msg_hdr("HDF debug timer output started")
//     if (dbg_report_hdf5) call log_msg("  RANK             INIT            WRITE            CLOSE       CLOSE FILE       WORK TOTAL             WAIT            TOTAL           %-WAIT")
//     t_wait = t_write_s - t_init_f + t_close_s - t_write_f + t_closef_s - t_close_f + t_f - t_closef_f
//     t_init = t_init_f - t_init_s
//     t_write = t_write_f - t_write_s
//     t_close = t_close_f - t_close_s
//     t_closef = t_closef_f - t_closef_s

//     t_total_nowait = t_init + t_write + t_close + t_closef
//     t_total = t_f - t_s
//     p_wait = t_wait / t_total

//     ! Magic number '256' corresponds to the length of msgstr of course
//     if ( myrankc .gt. 0 ) then
//       write(msgstr,'(I6.6,X,F16.10,X,F16.10,X,F16.10,X,F16.10,X,F16.10,X,F16.10,X,F16.10,X,F16.10)') myrankc, t_init, t_write, t_close, t_closef, t_total_nowait, t_wait, t_total, 100.0*p_wait
//       call MPI_Send(msgstr, 256, MPI_CHARACTER, 0, tag, Comm_cart, err)
//     else
//       write(msgstr,'(I6.6,X,F16.10,X,F16.10,X,F16.10,X,F16.10,X,F16.10,X,F16.10,X,F16.10,X,F16.10)') myrankc, t_init, t_write, t_close, t_closef, t_total_nowait, t_wait, t_total, 100.0*p_wait
//       if (dbg_report_hdf5) call log_msg(msgstr)
//       do i=1, nprocs-1
//         call MPI_Recv(msgstr, 256, MPI_CHARACTER, i, tag, Comm_cart, status, err)
//         if (dbg_report_hdf5) call log_msg(msgstr)
//       end do
//     end if

//     call log_msg_hdr("HDF debug timer output finished")
//   end if

// end subroutine dump_scalar_phdf5
}
            

hid_t hdf5Typeof(T)() {
  static if ( is(T == int) ) {
    return H5T_NATIVE_INT_g;
  }
  else static if ( is(T == double) ) {
    return H5T_NATIVE_DOUBLE_g;
  }
  else {
    static assert(0, "Datatype not implemented for HDF5.");
  }
}
         