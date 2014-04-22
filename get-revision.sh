#!/bin/bash

GITCMD=git

# First, check if git is available at all...
type $GITCMD > /dev/null 2>&1
DIFFCODE=$?
if [[ "$DIFFCODE" -ne 0 ]]
then
  echo "ERROR: Git not found."
  exit 1
fi

# Run git diff to check for local changes. 
# Return code 0 indicates no changes, 1 indicates changes are present.
# Exit code 129 is an error when not inside a Git repo. 
# Use code 129 to avoid errors for the describe and log commands.
$GITCMD diff --quiet 2> /dev/null
DIFFCODE=$?

if [[ "$DIFFCODE" -ne 129 ]]
then
  FULLHASH=`$GITCMD rev-parse HEAD`
  DESC=`$GITCMD describe --always --tag`
  BRANCH=`$GITCMD rev-parse --abbrev-ref HEAD | tr '\n' ' ' | sed -e 's/ *$//'`
  LOCALCHANGED=${DIFFCODE}
  LOCALCHANGES=`$GITCMD diff --stat`
else
  FULLHASH="unknown"
  DESC="exported"
  BRANCH="exported"
  LOCALCHANGED=-1
  LOCALCHANGES=""
fi

# Code for revision.d
read -d '' DVARS <<EOF

// Written in the D programming language.
module dlbc.revision;

immutable {

// Git commit information.
string revisionHash = \"$FULLHASH\";
string revisionDesc = \"$DESC\";
string revisionBranch = \"$BRANCH\";
int    revisionChanged = $LOCALCHANGED;
string revisionChanges = \"$LOCALCHANGES\";

// This string exists as a string literal to be able to use
// the 'strings' command to retrieve the version of the executable,
// even when it cannot be run on the current platform.
//   strings dlbc | grep "DLBC VERSION"
string revisionString = \"DLBC VERSION $DESC $BRANCH $LOCALCHANGED\";

}


EOF

echo "$DVARS"

