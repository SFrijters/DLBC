#!/bin/bash -e

for data in density-red density-blue velocity-red velocity-blue mask force-red force-blue ; do

  h5diff output/${data}-poiseuille-2d-*-t00100000.h5 reference-data/${data}-poiseuille-2d-*-t00100000.h5 /OutArray

done
