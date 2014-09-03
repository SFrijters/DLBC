#!/bin/bash -e

for sigma in 0.003125 0.03125 0.3125; do
for np in 1 2; do
for solver in SOR; do
for data in mask elChargeN elChargeP elPot elDiel elField; do

  h5diff output/sigma${sigma}-np${np}-${solver}/${data}-diffusive-flux-*-t00000000.h5 reference-data/sigma${sigma}-np${np}-${solver}/${data}-diffusive-flux-*-t00000000.h5 /OutArray

done
done
done
done
