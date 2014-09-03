#/bin/bash -e

rm -f stdout.txt

for sigma in 0.003125 0.03125 0.3125 ; do

for np in 1 2; do

for solver in SOR; do

  cat input-parameters-diffusive-flux-2D.template | sed -e "s/^init.chargeDensitySolid =/init.chargeDensitySolid = ${sigma}/" | sed -e "s/^poisson.solver =/poisson.solver = ${solver}/" | sed -e "s/^nc =/nc = [${np}, 1]/" > input-file.tmp 

  mpirun -np ${np} ./dlbc-d2q9-release -p input-file.tmp -v Information | tee -a stdout.txt

done

done

done

rm -f input-file.tmp


