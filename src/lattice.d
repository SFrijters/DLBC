import logging;
import parameters;
import parallel;

import std.stdio;

import unstd.multidimarray;

Field!int L;

/// Create lattice L for every CPU, according to cartesian decomposition and halo size
void createLocalLattice() {
  int nx, ny, nz;
  
  // Check if we can reconcile global lattice size with CPU grid
  if (P.nx % M.ncx != 0 || P.ny % M.ncy != 0 || P.nz % M.ncz != 0) {
    writeLogRF("Cannot divide lattice evenly.");
    throw new Exception("Lattice division exception");
  }

  // Calculate local lattice size
  nx = cast(int) (P.nx / M.ncx);
  ny = cast(int) (P.ny / M.ncy);
  nz = cast(int) (P.nz / M.ncz);

  // Check for bogus halo
  int haloSize = P.haloSize;
  if (haloSize < 1) {
    writeLogRF("Halo size < 1 not allowed.");
    throw new Exception("Halo size exception");
  }

  writeLogRI("Initializing %d x %d x %d local lattice with halo of thickness %d.", nx, ny, nz, P.haloSize);

  // Create lattice
  L = Field!int(nx, ny, nz, P.haloSize);

}

struct Halo {
  int[3] ns, nr, ps, pr;
  MPI_Datatype mpiType;
  int extent;
}

struct Buffers(T) {
  MultidimArray!(T, 2LU) x, y, z;

  this (const int nx, const int ny, const int nz, const int haloSize) {
    x = multidimArray!T(ny + 2*haloSize, nz + 2*haloSize);
    y = multidimArray!T(nx + 2*haloSize, nz + 2*haloSize);
    z = multidimArray!T(nx + 2*haloSize, ny + 2*haloSize);
  }
}

struct Field(T) {
  MultidimArray!(T, 3LU) arr;
  Buffers!T buffers;

  MultidimArray!(T, 3LU) sbuffer, rbuffer;
 
  Halo halo;

  int nx, ny, nz;
  int nxH, nyH, nzH;
  int haloSize;
  int mpiType;
  
  MPI_Status mpiStatus;

  this (const int nx, const int ny, const int nz, const int haloSize) {

    this.nx = nx;
    this.ny = ny;
    this.nz = nz;
    this.haloSize = haloSize;
    this.nxH = haloSize + nx + haloSize;
    this.nyH = haloSize + ny + haloSize;
    this.nzH = haloSize + nz + haloSize;
    
    arr = multidimArray!T(nxH, nyH, nzH);
   
    arr[] = M.rank;
    arr[0, 0..$, 0..$] = -1;
    arr[$ - 1, 0..$, 0..$] = -1;
    arr[0..$, 0, 0..$] = -1;
    arr[0..$, $ - 1, 0..$] = -1;
    arr[0..$, 0..$, 0] = -1;
    arr[0..$, 0..$, $ - 1] = -1;

    static if ( is(T == int) ) {
      this.mpiType = MPI_INT;
    }
    else {
      static assert("Datatype not implemented.");
    }

    
    foreach(slice; arr.byTopDimension) {
      //      writeln(typeof(slice));
      //showSlice(slice);
    }

    // halo.ns = build_chunk_mpitype(halo, [0, 1], [0, nyH - 1], [0, nzH - 1]);

    //writeln(typeof(R));

  }
 

  void haloExchange() {
    // Send to positive x
    rbuffer = multidimArray!T(haloSize, nyH, nzH);
    sbuffer = arr[$-2*haloSize-1..$ - haloSize-1, 0..$, 0..$].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nyH * nzH, MPI_INT, M.nbx[1], 0, rbuffer._data.ptr, nyH * nzH, mpiType, M.nbx[0], 0, M.comm, &mpiStatus);
    arr[0..haloSize, 0..$, 0..$] = rbuffer;
    owriteLogI(arr[0,1,0..$].toString());

    // Send to negative x
    sbuffer = arr[1..1+haloSize, 0..$, 0..$].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nyH * nzH, MPI_INT, M.nbx[0], 0, rbuffer._data.ptr, nyH * nzH, mpiType, M.nbx[1], 0, M.comm, &mpiStatus);
    arr[$ - haloSize .. $, 0..$, 0..$] = rbuffer;
    owriteLogI(arr[$-1,1,0..$].toString());

    // Send to positive y
    rbuffer = multidimArray!T(nxH, haloSize, nzH);
    sbuffer = arr[0..$, $-2*haloSize-1..$ - haloSize-1, 0..$].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nxH * nzH, MPI_INT, M.nby[1], 0, rbuffer._data.ptr, nxH * nzH, mpiType, M.nby[0], 0, M.comm, &mpiStatus);
    arr[0..$, 0..haloSize, 0..$] = rbuffer;
    owriteLogI(arr[1,0,0..$].toString());

    // Send to negative y
    rbuffer = arr[0..$, 1..1+haloSize, 0..$].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nxH * nzH, MPI_INT, M.nby[0], 0, rbuffer._data.ptr, nxH * nzH, mpiType, M.nby[1], 0, M.comm, &mpiStatus);
    arr[0..$, $ - haloSize .. $, 0..$] = rbuffer;
    owriteLogI(arr[1, $-1,0..$].toString());

    // Send to positive z
    rbuffer = multidimArray!T(nxH, nyH, haloSize);
    sbuffer = arr[0..$, 0..$, $-2*haloSize-1..$ - haloSize-1].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nxH * nyH, MPI_INT, M.nbz[1], 0, rbuffer._data.ptr, nxH * nyH, mpiType, M.nbz[0], 0, M.comm, &mpiStatus);
    arr[0..$, 0..$, 0..haloSize] = rbuffer;
    // owriteLogI(arr[1,0,0..$].toString());

    // Send to negative z
    rbuffer = arr[0..$, 0..$, 1..1+haloSize].dup;
    MPI_Sendrecv(sbuffer._data.ptr, nxH * nyH, MPI_INT, M.nbz[0], 0, rbuffer._data.ptr, nxH * nyH, mpiType, M.nbz[1], 0, M.comm, &mpiStatus);
    arr[0..$, 0..$, $ - haloSize .. $] = rbuffer;
    // owriteLogI(arr[1, $-1,0..$].toString());

    writeLogRI(arr.toString());

    // buffer = arr[$ - haloSize*2..$ - haloSize, 0..$, 0..$].dup;
    // MPI_Sendrecv(buffer._data.ptr, nyH * nzH, MPI_INT, M.nbx[0], 0, buffer._data.ptr, nyH * nzH, MPI_INT, M.nbx[1], 0, M.comm, &mpiStatus);
    // arr[$ -haloSize .. $, 0..$, 0..$] = buffer;



    //    writeLogRI(arr.toString());

    // writeln(buffer.elements);
    // writeln(nyH*nzH);

    // MPI_Irecv(buffer._data.ptr, (nyH * nzH), MPI_INT, M.nbx[1], 0, M.comm, &mpiStatus);
    // MPI_Isend(buffer._data.ptr, (nyH * nzH), MPI_INT, M.nbx[0], 0, M.comm);

    // MPI_Sendrecv(buffer._data.ptr, nyH * nzH, MPI_INT, M.nbx[1], 0, buffer._data.ptr, nyH * nzH, MPI_INT, M.nbx[0], 0, M.comm, &mpiStatus);

    //arr[1, 0..$, 0..$] = buffer;

    //MpiBarrier();


  }


  void showSlice(MultidimArray!(T, 2LU) slice) {
    foreach(row; slice.byTopDimension) {
      writeLogI(row.toString);
    }
  }

//   void build_all_chunk_mpitypes(N, h, mpitype, extent) {

//   integer,       intent(in)    :: extent, mpitype
//   type(halo),    intent(inout) :: h
//   type(lbe_site),intent(inout) :: N(1-halo_extent:,1-halo_extent:,1-halo_extent:)

//   integer :: he, h1

//   ! Set base MPI type of the halo
//   h%mpitype = mpitype

//   ! Set halo extent of the halo
//   h%extent = extent

//   ! just abbreviations
//   he = h%extent
//   h1 = h%extent - 1

//   ! x swaps (still restricted y/z-range: data outside is out-dated)
//   call build_chunk_mpitype(N,(/1,      he/),(/1,      ny/),(/1,      nz/),h,h%ls(1))
//   call build_chunk_mpitype(N,(/nx-h1,  nx/),(/1,      ny/),(/1,      nz/),h,h%us(1))
//   call build_chunk_mpitype(N,(/-h1,     0/),(/1,      ny/),(/1,      nz/),h,h%lr(1))
//   call build_chunk_mpitype(N,(/nx+1,nx+he/),(/1,      ny/),(/1,      nz/),h,h%ur(1))

//   ! y swaps (full x-range - up-to-date data was received in x-swaps)
//   call build_chunk_mpitype(N,(/-h1, nx+he/),(/1,      he/),(/1,      nz/),h,h%ls(2))
//   call build_chunk_mpitype(N,(/-h1, nx+he/),(/ny-h1,  ny/),(/1,      nz/),h,h%us(2))
//   call build_chunk_mpitype(N,(/-h1, nx+he/),(/-h1,     0/),(/1,      nz/),h,h%lr(2))
//   call build_chunk_mpitype(N,(/-h1, nx+he/),(/ny+1,ny+he/),(/1,      nz/),h,h%ur(2))

//   ! z swaps (even full y-range - after z swap all data is complete)
//   call build_chunk_mpitype(N,(/-h1, nx+he/),(/-h1, ny+he/),(/1,      he/),h,h%ls(3))
//   call build_chunk_mpitype(N,(/-h1, nx+he/),(/-h1, ny+he/),(/nz-h1,  nz/),h,h%us(3))
//   call build_chunk_mpitype(N,(/-h1, nx+he/),(/-h1, ny+he/),(/-h1,     0/),h,h%lr(3))
//   call build_chunk_mpitype(N,(/-h1, nx+he/),(/-h1, ny+he/),(/nz+1,nz+he/),h,h%ur(3))

// end subroutine build_all_chunk_mpitypes

  int build_chunk_mpitype(const Halo h, const int[2] xr, const int[2] yr, const int[2] zr) {
    // type(halo),     intent(in)  :: h
    // type(lbe_site), intent(in)  :: N(1-halo_extent:, 1-halo_extent:, 1-halo_extent:)
    // integer,        intent(in)  :: xr(2), yr(2), zr(2) ! chunk ranges for each dim.
    // integer,        intent(out) :: cmt ! type to be built

    // integer(kind=MPI_ADDRESS_KIND) :: addr1, addr2, base, offset, stride
    // integer(kind=MPI_ADDRESS_KIND) :: displs(1)
    MPI_Aint addr1, addr2, base, offset, stride;
    MPI_Aint[1] displs;
    MPI_Datatype bmt, cmt; // base MPI type
    MPI_Datatype xrow_mt, xyplane_mt, xyzchunk_mt; // temporary MPI data types
    int cnt;
    int[1] lengths; // for mpi_type_create_hindexed()
    int mpierror;

    immutable int blocklength = 1;

    bmt = MPI_INT;

    writeln(bmt);

    // MPI datatype for slices like Field[xr(1) .. xr(2), y, z]
    cnt = xr[1] - xr[0];
    writeln(cnt);
    mpierror = MPI_Get_address(&arr[0,0,0], &addr1);
    writeLogRD("build_chunk_mpitype, MPI_Get_address : x, 1, 1, 1 returned %d", mpierror);
    mpierror = MPI_Get_address(&arr[1,0,0], &addr2);
    writeLogRD("build_chunk_mpitype, MPI_Get_address : x, 2, 1, 1 returned %d", mpierror);
    stride = addr2 - addr1;
    writeln(stride);
    mpierror = MPI_Type_create_hvector(cnt, blocklength, stride, bmt, &xrow_mt);
    writeLogRD("build_chunk_mpitype: MPI_Type_create_hvector : x returned %d", mpierror);
    mpierror = MPI_Type_commit(&xrow_mt);

    MPI_Aint extent;
    MPI_Type_extent(xrow_mt, &extent);
    writeln(extent);

    //    mpierror = MPI_Type_commit(&xrow_mt);

    // MPI datatype for slices like Field[xr(1) .. xr(2), yr(1) .. yr(2) , z]
    cnt = yr[1] - yr[0];
    mpierror = MPI_Get_address(&arr[0,0,0], &addr1);
    writeLogRD("build_chunk_mpitype, MPI_Get_address : y, 1, 1, 1 returned %d", mpierror);
    mpierror = MPI_Get_address(&arr[0,1,0], &addr2);
    writeLogRD("build_chunk_mpitype, MPI_Get_address : y, 1, 2, 1 returned %d", mpierror);
    stride = addr2 - addr1;
    writeln(stride);
    mpierror = MPI_Type_create_hvector(cnt, blocklength, stride, xrow_mt, &xyplane_mt);
    writeLogRD("build_chunk_mpitype: MPI_Type_create_hvector : y returned %d", mpierror);
    mpierror = MPI_Type_commit(&xyplane_mt);

    // mpierror = MPI_Type_commit(&xyplane_mt);

    // MPI datatype for whole chunk Field[xr(1) .. xr(2), yr(1) .. yr(2), zr(1) .. zr(2)]
    cnt = zr[1] - zr[0];
    mpierror = MPI_Get_address(&arr[0,0,0], &addr1);
    writeLogRD("build_chunk_mpitype, MPI_Get_address : z, 1, 1, 1 returned %d", mpierror);
    mpierror = MPI_Get_address(&arr[0,0,1], &addr2);
    writeLogRD("build_chunk_mpitype, MPI_Get_address : z, 1, 1, 2 returned %d", mpierror);
    stride = addr2 - addr1;
    writeln(stride);
    mpierror = MPI_Type_create_hvector(cnt, blocklength, stride, xyplane_mt, &xyzchunk_mt);
    writeLogRD("build_chunk_mpitype: MPI_Type_create_hvector : z returned %d", mpierror);
    mpierror = MPI_Type_commit(&xyzchunk_mt);

    // Position of the beginning of the chunk relative to the beginning of N
    mpierror = MPI_Get_address(&arr, &base);
    writeLogRD("build_chunk_mpitype, MPI_Get_address : base returned %d", mpierror);
    mpierror = MPI_Get_address(&arr[xr[0], yr[0], zr[0]], &offset);
    writeLogRD("build_chunk_mpitype, MPI_Get_address : offset returned %d", mpierror);
    offset = offset - base;

    writeln(xrow_mt, xyplane_mt, xyzchunk_mt);


    // cmt becomes a datatype like xyzchunk_mt but relative to base
    cnt = 1;
    lengths[0] = 1;
    displs[0] = offset;
    mpierror = MPI_Type_create_hindexed(cnt, lengths, displs, MPI_DOUBLE, &cmt);
    writeLogRD("build_chunk_mpitype, MPI_Type_create_hindexed returned %d", mpierror);
    mpierror = MPI_Type_commit(&cmt);
    writeLogRD("build_chunk_mpitype, MPI_Type_commit returned %d", mpierror);
    return cmt;
  }

// end subroutine build_chunk_mpitype

// subroutine halo_exchange(N, h)
//   implicit none

//   type(lbe_site), intent(inout) :: N(1-halo_extent:,1-halo_extent:,1-halo_extent:)
//   type(halo), intent(inout)     :: h

//   integer, parameter :: sendcount = 1
//   integer, parameter :: sendtag   = 0
//   integer, parameter :: recvcount = 1
//   integer, parameter :: recvtag   = 0

//   integer :: k, mpierror
//   integer :: status(MPI_STATUS_SIZE)

//   do k = 1,3
//     call MPI_Sendrecv&   ! send "downward"
//          &( N, sendcount, h%ls(k), nnprocs(k,1), sendtag&
//          &, N, recvcount, h%ur(k), nnprocs(k,2), recvtag&
//          &, comm_cart, status, mpierror)
//     if(mpierror /= 0) then
//        write(msgstr, "('Halo exchange MPI_Sendrecv for k = ',I0,' , downward.')") k
//        DEBUG_CHECKMPI(mpierror, msgstr)
//     end if
//     call MPI_Sendrecv&   ! send "upward"
//          &( N, sendcount, h%us(k), nnprocs(k,2), sendtag&
//          &, N, recvcount, h%lr(k), nnprocs(k,1), recvtag&
//          &, comm_cart, status, mpierror)
//     if(mpierror /= 0) then
//        write(msgstr, "('Halo exchange MPI_Sendrecv for k = ',I0,' , upward.')") k
//        DEBUG_CHECKMPI(mpierror, msgstr)
//     end if
//   end do

// end subroutine halo_exchange

  void fillWithRank() {
    for(int i=0;i<L.nxH;i++) {
      for(int j=0;j<L.nyH;j++) {
	for(int k=0;k<L.nzH;k++) {
	  //	  R[k][j][i] = M.rank;
	}
      }
    }
  }

}

