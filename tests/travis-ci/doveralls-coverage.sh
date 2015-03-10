#!/bin/bash

if [ -z "$1" ]; then
    DC=dmd
else
    DC=$1
fi

if [ -z "$2" ]; then
    DUMP=0
else
    DUMP=1
fi

if [ "${DC}" == "dmd" ]; then
    ./tests/runnable/process-tests.py --coverage --dub-compiler ${DC} --only-first
    cp tests/coverage/*.lst .
    if [[ "$DUMP" == 1 ]]; then
	dub run --compiler ${DC} doveralls -- -d > $2
    else
	dub run --compiler ${DC} doveralls
    fi
    rm -f *.lst
else
    echo "Code coverage is performed only with dmd."
fi

