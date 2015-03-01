
for DP in 1 2 5 10; do
for ER in 0.0199 0.04 0.08 0.12 0.18 0.24 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37; do
for f in droplet-eps_r${ER}-eps_b0.378-phi_dropz${DP} ; do 
  EB=`h5totxt -x 0 -y 0 output/${f}/cp-elDiel-dielectric-droplet-2d-*-t00005000.h5`
  ER=`h5totxt -x 31 -y 31 output/${f}/cp-elDiel-dielectric-droplet-2d-*-t00005000.h5` 
  D=`grep -nH '<LAPLACE>' stdout-${f}.txt | tail -n 1 | sed -e "s/stdout-droplet-eps_r\([0-9\.]*\)-eps_b\([0-9\.]*\)-phi_dropz\([0-9\.]*\)\.txt\:[0-9]*\:\[N\] <LAPLACE>/\1 \2 \3/"`
  echo $D $ER $EB
done | sort -n -k 1,1 -k 2,2 -k 3,3 >> combined-phi-dropz${DP}.txt
done
done
