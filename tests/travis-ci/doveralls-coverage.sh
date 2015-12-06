#!/bin/bash

function run_tests {
    if [ -z "$1" ]; then
        DUMP=0
    else
        DUMP=1
    fi
    echo "Removing old coverage information"
    rm -f *.lst
    rm -rf ./tests/coverage
    ./tests/runnable/process-tests.py --coverage --dub-compiler ${DC} --only-first
    cp ./tests/coverage/*.lst .
    if [[ "$DUMP" == 1 ]]; then
	dub run --compiler ${DC} doveralls -- -d > $1
    else
	dub run --compiler ${DC} doveralls
    fi
    rm -f *.lst
}

if [ -z "$1" ]; then
    DC=dmd
else
    DC=$1
fi

if [ "${DC}" == "dmd" ]; then
    if [ -z "$2" ]; then
        run_tests $3
    else
        dmd --version | grep "$2"
        VC=$?
        if [ "$VC" -eq 0 ]; then
            run_tests $3
        else
            echo "Code coverage is performed only with dmd version $2, but found" `dmd --version`
        fi
    fi
else
    echo "Code coverage is performed only with dmd."
fi

