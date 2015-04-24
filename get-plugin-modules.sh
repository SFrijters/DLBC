#!/bin/bash

PWD=`pwd`
cd src/dlbc/plugins

# Code for plist.d
read -d '' DVARS <<EOF
// Written in the D programming language.

/**
   List of plugin modules that have parameters to be registered.

   Copyright: Stefan Frijters 2011-2015

   License: \$(HTTP www.gnu.org/licenses/gpl-3.0.txt, GNU General Public License, version 3 (GPL-3.0)).

   Authors: Stefan Frijters
*/

module dlbc.plugins.plist;

import std.typecons;

alias parameterSourcePluginModules = TypeTuple!(

EOF

echo "$DVARS"

for f in `find . -name "*.d" | sort`; do
    grep '@("param")' --quiet $f
    NOT_FOUND=$?
    if [[ "$NOT_FOUND" -eq 0 ]]; then
	MNAME=`echo $f | sed -e 's/^\.\//dlbc.plugins./' -e 's/\.d$//' -e 's/\//./'`
	echo "  \"$MNAME\","
    fi
done

echo ");"

cd $PWD

