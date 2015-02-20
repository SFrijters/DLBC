#!/bin/bash

# Set compiler
if [ -z "$1" ]; then
    DC=dmd
else
    DC=$1
fi

./tests/runnable/process-tests.py --build-all --dub-compiler ${DC} --dub-force

