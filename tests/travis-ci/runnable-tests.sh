#!/bin/bash

if [ -z "$1" ]; then
    DC=dmd
else
    DC=$1
fi

if [ "${DC}" == "dmd" ]; then
    echo "Running only the first subtest of each test, in fast mode. Lax comparison is enabled."
    ./tests/runnable/process-tests.py --dub-compiler ${DC} --only-first --compare-lax --fast
else
    echo "Runnable tests are performed only with dmd."
fi

