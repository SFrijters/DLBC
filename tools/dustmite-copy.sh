#!/bin/bash

if [ -z "$1" ]; then
    echo "Please specify target path"
    exit -1
fi

CD=`pwd`

mkdir $1
cp -r * $1
cd $1

make clean
cp $CD/src/dlbc/revision.d src/dlbc/.

cat Makefile | sed 's/src\/dlbc\/revision.d: .git\/HEAD .git\/index/src\/dlbc\/revision.d:/' | sed 's/.\/get-revision.sh > $@/.\/get-revision.sh/' > Makefile.tmp
mv Makefile.tmp Makefile
rm -rf tests
rm -rf doc
rm -rf bootDoc
rm -rf d-test
rm -rf testdoc
for f in `find . -name "*.git*"`; do echo $f; rm -rf $f ; done

