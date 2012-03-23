#!/bin/bash -l
#
# This script will attempt to build the PLFS source. It will need
# to know where the source files are (1st command line parameter)
# and where to put the compiled binaries (second command line
# parameter). If the build is successful, the script will return an
# exit status of 0. If the build fails, an exit status of 1 will
# be returned.
#
# The location to pass as the source directory is the directory that
# everything should be compiled in. That is, this script will attempt
# to run the compilation process directly in the path given by the
# first command line parameter.

req_m4_version="1.4.14"
req_autoconf_version="2.65"
req_automake_version="1.11.1"
req_libtool_version="2.2.6b"

# Where to put source files
srcdir="$1"
# Where to put the binaries
instdir="$2"

if [ "$srcdir" == "" ] || [ "$instdir" == "" ]; then
  echo "Error: missing one or more command line parameters."
  echo ""
  echo "Usage:"
  echo "$0 SRC INST"
  echo -e "\tSRC is where the PLFS source that is to be built is located."
  echo -e "\tINST is the destination for the PLFS compiled binaries."
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

echo "Entering ${srcdir}" 
if [ ! -d "${srcdir}" ]; then
  echo "Error: ${srcdir} does not exist"
  exit 1
fi
cd ${srcdir}

# Build the trunk source
# See if we need to run autogen.sh
if [ -e configure ]; then
    echo "configure script already present; will not attempt to run autogen.sh"
else
    # Need to run autogen.sh.
    echo "Running autogen.sh"
    ./autogen.sh
    check_exit $? "Autogen.sh process"
fi

# See if we need to clean out a previous compilation attempt. We want to start
# over completely from the configure step.
if [ -e Makefile ]; then
    echo "Compilation seems to have been attempted in the plfs source directory already. Running 'make distclean'."
    make distclean
fi

echo "Running configure script"
if [ $instdir == "" ]; then
  ./configure --disable-silent-rules
else
  ./configure --prefix=$instdir --disable-silent-rules
fi
check_exit $? "Configure process"

echo "Running make"
make
check_exit $? "Make process"

# Remove the old install directory
if [ -d $instdir ]; then
  echo "Removing old install directory"
  rm -rf $instdir 2>&1
  if [ -d $instdir ]; then
    echo "Error: Unable to remove old installation"
    exit 1
  fi
fi

echo "Running make install"
make install

# A check for versions of plfs that don't split binaries into bin and sbin
if [ ! -d $instdir/sbin ]; then
    cp -r $instdir/bin $instdir/sbin
fi

check_exit $? "Make install process"
