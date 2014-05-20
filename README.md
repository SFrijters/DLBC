D Lattice Boltzmann Code
===

This is a home project to implement the lattice Boltzmann method using the D programming language. The goal is to prove the suitability of the D programming language for scientific computing / HPC. Parallelization has been implemented through the use of MPI, and parallel I/O is handled through HDF5.

D HDF5 bindings have been added as a submodule [hdf5-d](http://github.com/SFrijters/hdf5-d), while D MPI bindings are still a work in progress and are currently handled through a partial header translation.

Multidimensional arrays have been added using Denis Shelomovskij's [Unstandard library](https://bitbucket.org/denis-sh/unstandard).

Documentation is generated using DDoc and Jakob Ovrum's [bootDoc](http://github.com/JakobOvrum/bootDoc).

## License

The simulation code is made available under the [GPL-3.0 license](http://www.gnu.org/licenses/gpl-3.0.txt). The submodules are subject to their own licenses.

