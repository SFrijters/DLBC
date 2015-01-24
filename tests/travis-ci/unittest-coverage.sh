#!/bin/bash

if [ -z "$1" ]; then
    DC=dmd
else
    DC=$1
fi

if [ -z "$2" ]; then
    TRAVIS=0
else
    TRAVIS=1
fi

if [ "${DC}" == "dmd" ]; then
    for c in d3q19 d2q9 d1q5 d1q3; do
	./dlbc-${c}-test --version
	grep -e 'covered$' *.lst | tee cov-${c}.log
    done

    # Doveralls
    if [ "$TRAVIS" -gt 0 ]; then
	c=d3q19
	dub test --compiler ${DC} -b unittest-cov -c ${c}
	dub run  --compiler ${DC} doveralls 
    fi
else
    echo "Code coverage is performed only with dmd."
fi

