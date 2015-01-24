## D Lattice Boltzmann Code
[![Build Status](https://travis-ci.org/SFrijters/DLBC.svg?branch=master)](https://travis-ci.org/SFrijters/DLBC) [![Coverage Status](https://coveralls.io/repos/SFrijters/DLBC/badge.svg)](https://coveralls.io/r/SFrijters/DLBC)

This code is an implementation of the [lattice Boltzmann method](http://en.wikipedia.org/wiki/Lattice_Boltzmann_methods) for simulating fluid dynamics, using the D programming language. The goal is to prove the suitability of the D programming language for scientific computing / HPC and provide a well-tested and well-documented benchmark code. Parallelization has been implemented through the use of MPI, and parallel I/O is handled through HDF5.

D HDF5 bindings have been added as a submodule [hdf5-d](http://github.com/SFrijters/hdf5-d), while D MPI bindings are still a work in progress and are currently handled through a partial header translation.

Multidimensional arrays have been added using a fork of Denis Shelomovskij's [Unstandard library](https://bitbucket.org/SFrijters/unstandard).

Documentation is generated using DDoc and Jakob Ovrum's [bootDoc](http://github.com/JakobOvrum/bootDoc).

### Features

- Fully parallelized code using MPI.
- Generic code that can use D3Q19, D2Q9, D1Q5 or D1Q3 lattices (other connectivities can be easily added when required).
- Fluid multicomponent model by Shan and Chen (implementation not properly validated yet).
- Static geometries with bounce-back boundary conditions.
- Effects of electric charges / fields, using a SOR solver for the Poisson equation.

### Requirements

- To build the code a D compiler is required (obviously). Because of the multidimensional array syntax, v2.066.0 or later is required. This code has so far only been tested with DMD; LDC and GDC will follow, including performance tests, as soon as all compilers have reached the 2.066.0 frontend.
- To run the simulation code, the MPICH 3.1 and HDF5 1.8.13 libraries are required.
- To run the tests, the HDF5 binaries are also required (in particular h5diff).
- To create the test result plots, python, matplotlib, h5py and numpy/scipy are required.

An example of an installation can be found in the Travis CI file. This does not include plotting / documentation requirements.

### Installation

DLBC can be compiled using [DUB](http://code.dlang.org/download).

     dub build -b release -c <configuration>

where &lt;configuration&gt; specifies the lattice connectivity and is one of d3q19 (default), d2q9, d1q5 or d1q3.

This will allow to easily select the desired compiler; the old Makefile uses dmd only. The Makefile will be deprecated and removed in good time.

### Future extensions

The first priority is currently to validate the Shan-Chen multicomponent model implementation. After this, more extensive documentation and a user guide will be added. As soon as the v2.066.0 compiler frontend is available for more compilers, there will be an attempt to optimize performance.

### Pull requests

Are welcomed!

### License

The simulation code is made available under the [GPL-3.0 license](http://www.gnu.org/licenses/gpl-3.0.txt). The submodules are subject to their own licenses.

