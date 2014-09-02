#/bin/bash

if [ ! -f ./dlbc-d2q9 ]; then
  echo "Please place executable ./dlbc-d2q9 in this folder."
  exit -1
fi

mkdir -p output/eq
mpirun -np 1 ./lbe -f input-file-eq | tee stdout.txt

for dropz in 1 2 5 10; do

for eps_b in 0.378; do

for eps_r in 0.0199 0.04 0.08 0.12 0.18 0.24 0.3 0.36 0.37 0.35 0.34 0.33 0.32 0.31; do
  GROUT=droplet-eps_r${eps_r}-eps_b${eps_b}-phi_dropz${dropz}
  IFN=input-file-${GROUT}
  cat input-parameters-dielectric-droplet-2D-sweep.txt | sed -e "s/^dropPhi =/dropPhi = [ ${dropz}, ${dropz}, 0.0, 0.0 ]/" | sed -e "s/^fluidDiel =/fluidDiel = [ ${eps_r}, ${eps_b} ]/" > ${IFN}

  mkdir -p output/${GROUT}/
  cp output-eq/cp/* output/${GROUT}/.

  mpirun -np 1 ./dlbc-d2q9 -p $IFN -r dielectric-droplet-2d-phi2-20140815T171518-t00002000 -v Information | tee stdout-${GROUT}.txt

done

done

done


