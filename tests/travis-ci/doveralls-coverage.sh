#!/bin/bash

if [ -z "$1" ]; then
    DC=dmd
else
    DC=$1
fi

if [ "${DC}" == "dmd" ]; then
    ./tests/runnable/run-tests.py --coverage-unittest --dub-compiler ${DC}
    cp tests/coverage/*.lst .
    dub run --compiler ${DC} doveralls
    rm -f *.lst
else
    echo "Code coverage is performed only with dmd."
fi

