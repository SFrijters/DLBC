#/bin/bash -e

for sigma in 0.003125 0.03125 0.3125 ; do

for np in 1 2; do

for solver in SOR; do

  cat input-parameters-diffusive-flux-1D.template | sed -e "s/^init.chargeDensitySolid =/init.chargeDensitySolid = ${sigma}/" | sed -e "s/^poisson.solver =/poisson.solver = ${solver}/" | sed -e "s/^nc =/nc = [${np}]/" > input-file.tmp 

  mpirun -np ${np} ./dlbc-d1q3-release -p input-file.tmp -v Fatal 

done

done

done

rm -f input-file.tmp


