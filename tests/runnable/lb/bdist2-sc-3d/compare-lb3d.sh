#!/bin/bash

D=1e-15

for T in 00000000 00000100; do
  h5diff -d $D -v reference-data/population-red-bdist2-sc-3d-*-t${T}.h5 reference-data-lb3d/od_pop_dlbc-sc_t${T}-*.h5
  h5diff -d $D -v reference-data/density-red-bdist2-sc-3d-*-t${T}.h5 reference-data-lb3d/od_dlbc-sc_t${T}-*.h5
  h5diff -d $D -v reference-data/population-blue-bdist2-sc-3d-*-t${T}.h5 reference-data-lb3d/wd_pop_dlbc-sc_t${T}-*.h5
  h5diff -d $D -v reference-data/density-blue-bdist2-sc-3d-*-t${T}.h5 reference-data-lb3d/wd_dlbc-sc_t${T}-*.h5
done
