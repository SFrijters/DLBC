#!/bin/bash

wget -O mpich-3.1.tar.bz2 https://www.dropbox.com/s/3k0i6xrop33y9dz/mpich-3.1.tar.bz2?dl=1
tar -xf mpich-3.1.tar.bz2

for f in mpich-3.1/bin/* ; do sudo ln -s `pwd`/$f /usr/bin/. ; done
for f in mpich-3.1/include/* ; do sudo ln -s `pwd`/$f /usr/include/. ; done
for f in mpich-3.1/lib/* ; do sudo ln -s `pwd`/$f /usr/lib/. ; done

wget -O hdf5-1.8.13-mpich-3.1.tar.bz2 https://www.dropbox.com/s/h50k3yu4om9hnz4/hdf5-1.8.13-mpich-3.1.tar.bz2?dl=1
tar -xf hdf5-1.8.13-mpich-3.1.tar.bz2

for f in hdf5-1.8.13-mpich-3.1/bin/* ; do sudo ln -s `pwd`/$f /usr/bin/. ; done
for f in hdf5-1.8.13-mpich-3.1/include/* ; do sudo ln -s `pwd`/$f /usr/include/. ; done
for f in hdf5-1.8.13-mpich-3.1/lib/* ; do sudo ln -s `pwd`/$f /usr/lib/. ; done

