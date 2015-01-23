#!/bin/bash

# WARNING: the first build is a release build; this will build the subpackages in release mode.
# They will not be rebuilt for the test builds, and this hides some unittest errors.

# Set compiler
DC=$1

for c in d3q19 d2q9 d1q5 d1q3; do
for b in release test; do
    echo "Building dlbc ~master configuration '${c}', build type ${b}, using ${DC}."
    time dub build --compiler=${DC} -c ${c} -b ${b} &> /dev/null
    mv dlbc-${c} dlbc-${c}-${b}
done
done

