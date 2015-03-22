#!/bin/bash

for f in *; do
    TF=`echo $f | sed -e 's/\(.*\)-[0-9]*T[0-9]*-\(t[0-9]*\)/\1-\2/'`
    if [ "$TF" != "$f" ]; then
	mv $f $TF
    fi
done

