#!/bin/bash -e

for g in 5 6; do
  mpirun -np 1 ./dlbc-d1q3-release -p input-parameters-laplace-d1q3.txt --parameter "lb.force.gcc = [ [ 0.0, $g ], [ $g, 0.0 ] ]" --parameter "lb.timesteps = 100000" -v Information # | tee stdout-d1q3-g${g}.txt
  mpirun -np 1 ./dlbc-d1q5-release -p input-parameters-laplace-d1q5.txt --parameter "lb.force.gcc = [ [ 0.0, $g ], [ $g, 0.0 ] ]" --parameter "lb.timesteps = 100000" -v Information # | tee stdout-d1q5-g${g}.txt
  mpirun -np 1 ./dlbc-d2q9-release -p input-parameters-laplace-d2q9.txt --parameter "lb.force.gcc = [ [ 0.0, $g ], [ $g, 0.0 ] ]" --parameter "lb.timesteps = 100000" -v Information # | tee stdout-d2q9-g${g}.txt
  mpirun -np 1 ./dlbc-d3q19-release -p input-parameters-laplace-d3q19.txt --parameter "lb.force.gcc = [ [ 0.0, $g ], [ $g, 0.0 ] ]" --parameter "lb.timesteps = 100000" -v Information # | tee stdout-d3q19-g${g}.txt
done

