#!/bin/bash -e

for data in elPot elChargeP elChargeN elField elDiel ; do

  h5diff output/${data}-liquidjunction-2d-*-t00001000.h5 reference-data/${data}-liquidjunction-2d-*-t00001000.h5 /OutArray

done
