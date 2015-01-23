#!/bin/bash

# Set compiler
DC=$1

for c in d3q19 d2q9 d1q5 d1q3; do
for b in release test; do
    echo "Building dlbc ~master configuration '${c}', build type ${b}, using ${DC}."
    time dub build --compiler=${DC} -c ${c} -b ${b} &> /dev/null
    mv dlbc-${c} dlbc-${c}-${b}
done
done

