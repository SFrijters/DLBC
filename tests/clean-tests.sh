#!/bin/bash

for d in `find . -name reference-data`; do
  TD=`echo $d | sed 's/reference-data//'`
  echo "=== Cleaning $TD ==="
  cd $TD
  make clean
  cd -
done
