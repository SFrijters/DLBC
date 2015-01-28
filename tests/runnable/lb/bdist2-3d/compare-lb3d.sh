#!/bin/bash

for T in 00000000 00000010; do
  h5diff -v reference-data/population-red-bdist2-3d-*-t${T}.h5 reference-data-lb3d/od_pop_dlbc-compat_t${T}-*.h5
  h5diff -v reference-data/density-red-bdist2-3d-*-t${T}.h5 reference-data-lb3d/od_dlbc-compat_t${T}-*.h5
  h5diff -v reference-data/population-blue-bdist2-3d-*-t${T}.h5 reference-data-lb3d/wd_pop_dlbc-compat_t${T}-*.h5
  h5diff -v reference-data/density-blue-bdist2-3d-*-t${T}.h5 reference-data-lb3d/wd_dlbc-compat_t${T}-*.h5
done
