#!/bin/bash

if [ -z "$1" ]; then
    echo "Please specify target path"
    exit -1
fi

CD=`pwd`

mkdir $1
cp -r src/ $1
cp Makefile $1
cat dub.json | sed 's/"preGenerateCommands": \[.*\],//' > $1/dub.json
cd $1

make clean
cp $CD/src/dlbc/revision.d src/dlbc/.
cp $CD/src/dlbc/plugins/plist.d src/dlbc/plugins/.

# Change directory to $1 and use 'dustmite . 'dub build 2>&1 | grep -qF something' to reduce.

