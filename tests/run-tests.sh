#!/bin/bash

for d in `find . -name reference-data`; do
  TD=`echo $d | sed 's/reference-data//'`
  echo "=== Testing $TD ==="
  cd $TD
  make
  cd -
done
