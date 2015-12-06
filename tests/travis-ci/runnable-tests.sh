#!/bin/bash

function run_tests {
    echo "Running only the first subtest of each test, in fast mode. Lax comparison is enabled."
    ./tests/runnable/process-tests.py --dub-compiler ${DC} --only-first --compare-lax --fast
}

if [ -z "$1" ]; then
    DC=dmd
else
    DC=$1
fi

if [ "${DC}" == "dmd" ]; then
    if [ -z "$2" ]; then
        run_tests
    else
        dmd --version | grep "$2"
        VC=$?
        if [ "$VC" -eq 0 ]; then
            run_tests
        else
            echo "Runnable tests are performed only with dmd version $2, but found" `dmd --version`
        fi
    fi
else
    echo "Runnable tests are performed only with dmd."
fi

