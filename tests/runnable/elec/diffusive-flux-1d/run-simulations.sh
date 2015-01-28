#!/bin/bash -e

for sigma  in 0.003125 0.03125 0.3125 ; do
for np     in 1 2; do
for solver in SOR; do
  mpirun -np ${np} ./dlbc-d1q3-release -p input-parameters-diffusive-flux-1D.txt --parameter "elec.init.chargeDensitySolid = ${sigma}" --parameter "elec.poisson.solver = ${solver}" --parameter "parallel.nc = [${np} ]" -v Fatal 
done
done
done

