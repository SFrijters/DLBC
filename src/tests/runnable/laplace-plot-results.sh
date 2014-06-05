#!/bin/bash

echo 'set terminal postscript color enh' > laplace-results.plt
echo 'set output "laplace-results.eps"' >> laplace-results.plt
echo 'set key ins left top' >> laplace-results.plt
echo 'set xrange [0:]' >> laplace-results.plt
echo 'set yrange [0:]' >> laplace-results.plt
echo 'plot \' >> laplace-results.plt

for gcc in 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00
do
  cat $1 | grep "^    1000 +${gcc}" | awk '{print $5, $6, $7}' > laplace-results-gcc${gcc}.dat
  echo "\"laplace-results-gcc${gcc}.dat\" u (2.0/\$1):(\$2-\$3) w lp t \"10 gcc = ${gcc}\", \\" >> laplace-results.plt
done

gnuplot 'laplace-results.plt'

