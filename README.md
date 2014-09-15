D Lattice Boltzmann Code
===

This is a home project to implement the lattice Boltzmann method using the D programming language. The goal is to prove the suitability of the D programming language for scientific computing / HPC. Parallelization has been implemented through the use of MPI, and parallel I/O is handled through HDF5.

D HDF5 bindings have been added as a submodule [hdf5-d](http://github.com/SFrijters/hdf5-d), while D MPI bindings are still a work in progress and are currently handled through a partial header translation.

Multidimensional arrays have been added using a fork of Denis Shelomovskij's [Unstandard library](https://bitbucket.org/SFrijters/unstandard).

Documentation is generated using DDoc and Jakob Ovrum's [bootDoc](http://github.com/JakobOvrum/bootDoc).

## Features

- Fully parallelized code.
- Generic code that can use D3Q19, D2Q9, D1Q5 or D1Q3 lattices (other connectivities can be easily added when required).
- Fluid multicomponent model by Shan and Chen (implementation not properly validated yet).
- Static geometries with bounce-back boundary conditions.
- Effects of electric charges / fields, using a SOR solver for the Poisson equation.

## Requirements

- To run the simulation code, the MPICH 3.1 and HDF5 1.8.13 libraries are required.
- To run the tests, the HDF5 binaries are also required (in particular h5diff).
- To create the test result plots, python, matplotlib, h5py and numpy/scipy are required.

## License

The simulation code is made available under the [GPL-3.0 license](http://www.gnu.org/licenses/gpl-3.0.txt). The submodules are subject to their own licenses.

