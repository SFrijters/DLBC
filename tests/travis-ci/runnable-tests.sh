#!/bin/bash

if [ -z "$1" ]; then
    DC=dmd
else
    DC=$1
fi

if [ "${DC}" == "dmd" ]; then
    ./tests/runnable/process-tests.py --dub-compiler ${DC} --only-first --compare-lax
else
    echo "Runnable tests are performed only with dmd."
fi

