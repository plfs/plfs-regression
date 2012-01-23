#!/bin/bash
#
# This script will check out a module for the ioandnetworking cvs repository
# located on LANL teamforge.

user="$1"

module="$2"

srcdir="$3"

if [ "$user" == "" ] || [ "$srcdir" == "" ] || [ "$module" == "" ]; then
  echo "Error: missing command line arguments"
  echo "Usage:"
  echo ""
  echo "$0 USER MODULE DIR"
  echo -e "\tUSER is the username to use to connect to LANL Teamforge."
  echo -e "\tMODULE is the module to check out of the REPO."
  echo -e "\tDIR is the location to put the checkout into"
  exit 1
fi

function check_exit {
  if [[ $1 == 0 ]]; then
    echo "$2 succeeded."
  else
    echo "Error: $2 failed."
    exit 1
  fi
}

# Make sure the directory to put the source in exists
if [ ! -d $srcdir ]; then
  mkdir -p $srcdir
  if [ ! -d $srcdir ]; then
    echo "Error: Unable to create $srcdir"
    exit 1
  fi
fi

echo "Entering $srcdir"
cd $srcdir

# Remove the old directory if it exists.
if [ -d "$module" ]; then
  echo "Removing old $module directory"
  rm -rf $module 2>&1
  if [ -d $module ]; then
    echo "Error: Unable to remove old $module directory"
    exit 1
  fi
fi

# Get the source from teamforge
echo "Checking out module $module source from ioandnetworking repository."
export CVS_RSH=ssh
cvs -z3 -d:ext:${user}@tf.lanl.gov:/cvsroot/ioandnetworking checkout $module
check_exit $? "$module CVS checkout"
exit 0
