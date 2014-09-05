#!/bin/bash
NT=`find . -name reference-data | wc -l`
CT=0
for d in `find . -name reference-data |sort`; do
  CT=$((CT+1))
  TD=`echo $d | sed 's/reference-data//'`
  echo "=== Testing $CT/$NT: $TD ==="
  cd $TD
  make
  cd -
done
