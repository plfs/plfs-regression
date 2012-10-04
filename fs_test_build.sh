#!/bin/bash

# Where the fs_test source is located
srcdir="$1"

# Where to copy the fs_test executable after compiling it
instdir="$2"

# What to append to the executable when copying it to the installation directory
suffix="$3"

# Check command line parameters
if [ -z "$srcdir" ] || [ -z "$instdir" ]; then
  echo "Error: missing one or more command line parameters."
  echo ""
  echo "Usage:"
  echo "$0 SRC INST SUFFIX"
  echo -e "\tSRC is where the fs_test source to be built is located."
  echo -e "\tINST is the directory to copy the fs_test executable in to."
  echo -e "\tSUFFIX is an optional string to append to the fs_test executable"
  echo -e "\twhen it is copied from SRC to INST. This way more than one version"
  echo -e "\tof the fs_test executable can be made available."
  exit 1
fi

if [ -n "$suffix" ]; then
  echo "Optional suffix $suffix given; this string will be appended to the"
  echo "fs_test's executable when copied to the installation directory."
fi

function check_exit {
  if [[ $1 == 0 ]]; then
    echo "$2 succeeded."
  else
    echo "Error: $2 failed."
    exit 1
  fi
}

# Grab the linking flags that we need
export MPI_LD=$RS_PLFS_LDFLAGS
export MPI_INC=$RS_PLFS_CFLAGS

# Echo the values of the needed environment variables
echo "The following are the values of the needed environment variables:"
echo "MY_MPI_HOST: $MY_MPI_HOST"
echo "MPI_CC: $MPI_CC"
echo "MPI_LD: $MPI_LD"
echo "MPI_INC: $MPI_INC"

# Check for the needed directories
if [ -d ${srcdir}/test_fs ]; then
  echo "${srcdir}/test_fs directory exists"
else
  echo "Error: ${srcdir}/test_fs directory does not exist"
  exit 1
fi

# Now build fs_test
echo "Entering directory ${srcdir}/test_fs"
cd ${srcdir}/test_fs

echo "Running make clean"
make clean
check_exit $? "fs_test make clean process"

echo "Running make fs_test"
make fs_test
check_exit $? "fs_test make process"

# Copy fs_test.x executable over to the installation directory

# Make the installation directory
echo "Creating $instdir"
mkdir -p "$instdir"
check_exit $? "Creating $instdir"

# Copy the executable over to the installation directory
echo "Copying fs_test.${MY_MPI_HOST}.x to $instdir/fs_test.${MY_MPI_HOST}.x$suffix"
cp fs_test.${MY_MPI_HOST}.x ${instdir}/fs_test.${MY_MPI_HOST}.x${suffix}
check_exit $? "Copying $srcdir/test_fs/src/fs_test.${MY_MPI_HOST} to $instdir/fs_test.${MY_MPI_HOST}.x${suffix}"

echo "Finished"
