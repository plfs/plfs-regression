#!/bin/bash
#
# This script will check out the PLFS source code from public
# sourceforge. It will check if the transaction was successful
# or not. An exit status of 0 means the checkout went fine; an
# exit status of 1 means the checkout failed for some reason.

# Where to put source files
srcdir="$1"

if [ "$srcdir" == "" ]; then
  echo "Error: missing location"
  echo "Usage:"
  echo ""
  echo "$0 DIR"
  echo -e "\tDIR is the location to put the checkout into"
  exit 1
fi

# Function to check the exit status of the last command (compares
# only against 0). Pass the exit status and a string that will
# be used in reporting whether the last command succeeded or not.
# If the exit status is not 0, this function will call "exit 1".
function check_exit {
  if [[ $1 == 0 ]]; then
    echo "$2 succeeded."
  else
    echo "Error: $2 failed."
    exit 1
  fi
}

# Create the workspace to download the source to and
# cd into that directory.
mkdir -p $srcdir
if [ ! -d $srcdir ]; then
  echo "Error: Unable to create $srcdir"
  exit 1
fi

cd $srcdir
echo "Entering $srcdir" 

if [ -d plfs ]; then
  echo "Removing old plfs directory"
  rm -rf plfs 2>&1
  if [ -d plfs ]; then
    echo "Error: Unable to remove old plfs directory"
    exit 1
  fi
fi

# Get the source directly from sourceforge
echo "Checking out plfs source from sourceforge"
svn co https://plfs.svn.sourceforge.net/svnroot/plfs/trunk plfs 2>&1
check_exit $? "PLFS SVN checkout"
exit 0
