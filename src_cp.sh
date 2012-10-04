#!/bin/bash
#
# This script will copy a directory containting source files to another
# directory. The first command line parameter is the directory that will be
# copied. The second command line parameter is the location to copy the
# directory to (the name of the new directory).

# The directory Where the source is located; the directory to copy
srcdir=$1

# The directory where the source will be copied to.
dstdir=$2

if [ "$srcdir" == "" ] || [ "$dstdir" == "" ]; then
  echo "Error: missing one or more command line parameters."
  echo ""
  echo "Usage:"
  echo "$0 SRC DST"
  echo -e "\tSRC is the source directory to copy from."
  echo -e "\tDST is the destination directory to copy to."
  exit 1
fi

if [ -d "$srcdir" ]; then
  # Remove old directory, if needed
  if [ -d "$dstdir" ]; then
    echo "Removing old $dstdir"
    rm -rf "$dstdir"
    if [ -d "$dstdir" ]; then
      echo "Error: Unable to remove old $dstdir"
      exit 1
    fi
  fi

  echo "Copying $srcdir to $dstdir"
  cp -r ${srcdir} ${dstdir}
  if [[ $? != 0 ]]; then
    echo "Error: problem with copying"
    exit 1
  fi
else
  echo "Error: unable to copy ${srcdir}: ${srcdir} directory does not exist"
  exit 1
fi
exit 0
