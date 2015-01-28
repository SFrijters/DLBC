#!/bin/bash -e

for data in density-red density-blue population-red population-blue; do

  h5diff output/${data}-bdist2-sc-3d-*-t00000100.h5 reference-data/${data}-bdist2-sc-3d-*-t00000100.h5 /OutArray

done
