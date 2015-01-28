#!/bin/bash -e

for data in density-red density-blue population-red population-blue; do

  h5diff output/${data}-bdist2-3d-*-t00000010.h5 reference-data/${data}-bdist2-3d-*-t00000010.h5 /OutArray

done
