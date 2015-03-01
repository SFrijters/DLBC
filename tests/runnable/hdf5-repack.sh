#!/bin/bash

for f in *h5; do
  echo $f
  h5repack -f SHUF -f GZIP=9 $f $f.tmp
  mv $f.tmp $f
done

