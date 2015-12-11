#!/bin/bash

function build_docs {
    dub build -b ddox
}

if [ -z "$1" ]; then
    DC=dmd
else
    DC=$1
fi

if [ "${DC}" == "dmd" ]; then
    if [ -z "$2" ]; then
        build_docs
    else
        dmd --version | grep "$2"
        VC=$?
        if [ "$VC" -eq 0 ]; then
            build_docs
        else
            echo "Documentation generation is performed only with dmd version $2, but found" `dmd --version`
        fi
    fi
else
    echo "Documentation generation is performed only with dmd."
fi

