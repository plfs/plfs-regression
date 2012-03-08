#!/bin/bash
#
# This script will extract openmpi source from a tarball, patch it against
# plfs, and compile it.

# Tarball to use
tarball="$1"
# Where to extract tarball
srcdir="$2"
# Where to put installation
openmpi_instdir="$3"
# Where the plfs source directory is located
plfs_srcdir="$4"
# Where plfs installation directory is located
plfs_instdir="$5"
# What platform file to use as a template
platform_file="$6"

if [ "$tarball" == "" ] || [ "$srcdir" == "" ] || 
   [ "$openmpi_instdir" == "" ] || [ "$plfs_srcdir" == "" ] || 
   [ "$plfs_instdir" == "" ] || [ "$platform_file" == "" ]; then
    echo "Error: missing one or more command line parameters."
    echo ""
    echo "Usage:"
    echo "$0 TB SRC OINST PSRC PINST PFILE"
    echo -e "\tTB is the tarball to extract openmpi from."
    echo -e "\tSRC is the directory to extract TB into."
    echo -e "\tOINST is the installation directory for openmpi."
    echo -e "\tPSRC is the PLFS source directory."
    echo -e "\tPINST is the installation directory for plfs so that openmpi can be patched against it."
    echo -e "\tPFILE is the platform file that will be used as a template when building open mpi."
    exit 1
fi

# These next two variables are used in an attempt to make changing versions of
# openmpi easier. I assume that the patch files will always contain the
# version number and start with ompi: ompi-1.4.3-plfs.patch. I also assume
# that the top-level directory in the openmpi tarball is the same as the
# tarball's name without ".tar.bz2". If those assumptions become false, then
# the following two variables (openmpi_name and ompi_name) need to calculated
# another way.

# Get the basename of the openmpi tarball, then figure out what name
# the directory will be when unarchived.
openmpi_name=`basename $tarball | sed 's/\.tar.*$//'`
# Short version of the openmpi name. Used in naming the plfs patch files.
ompi_name=`echo $openmpi_name | sed 's/open/o/'`

# Function to check the exit status of the last command
function check_exit {
    if [[ $1 == 0 ]]; then
        echo "$2 succeeded."
    else
        echo "Error: $2 failed."
        exit 1
    fi
}

# Remove the old install directory
if [ -d "$openmpi_instdir" ]; then
    echo "Removing old install directory $openmpi_instdir"
    rm -rf "$openmpi_instdir"
    if [ -d "$openmpi_instdir" ]; then
        echo "Error: Unable to remove old installation directory $openmpi_instdir."
        exit 1
    fi
fi

echo "Entering $srcdir"
if [ ! -d "$srcdir" ]; then
    echo "Error: $srcdir does not exist"
    exit 1
fi
cd "$srcdir"

# Remove old openmpi source
if [ -d "$openmpi_name" ]; then
    echo "Removing old openmpi source directory $openmpi_name"
    rm -r "${srcdir}/${openmpi_name}"
    if [ -d "$openmpi_name" ]; then
        echo "Error: Unable to remove old source directory ${srcdir}/${openmpi_name}"
    fi
fi

# Untar the archive
echo "Untarring the $tarball archive"
tar xjf $tarball
check_exit $? "Untar openmpi tarball"

# Go to the plfs source directory
echo "Entering $plfs_srcdir"
if [ ! -d "$plfs_srcdir" ]; then
    echo "Error: $plfs_srcdir does not exist."
    exit 1
fi
cd "$plfs_srcdir"

# Run the make_plfs_patch script
echo "Running ./scripts/make_plfs_patch"
./scripts/make_plfs_patch

# Go back to the directory containing the openmpi directory
echo "Entering $srcdir"
cd "$srcdir"

# Patch openmpi
echo "Patching openmpi"
patch -p0 < ${plfs_srcdir}/ad-patches/openmpi/${ompi_name}-plfs-prep.patch
check_exit $? "Using ompi-1.4.3-plfs-prep.patch"
patch -p0 < ${plfs_srcdir}/ad-patches/openmpi/${ompi_name}-plfs.patch
check_exit $? "Using ompi-1.4.3-plfs.patch"

# cd into the openmpi directory
echo "Entering $openmpi_name"
if [ ! -d "$openmpi_name" ]; then
    echo "Error: $openmpi_name directory not located in $srcdir"
    exit 1
fi
cd $openmpi_name

# Run autogen.sh
echo "Running ./autogen.sh"
./autogen.sh
check_exit $? "Autogen.sh process"

# Get the platform file from the plfs source directory, substituting the right
# paths for the regression environment.
echo "Generating platform file for openmpi compilation"
sed 's|REPLACE_PLFS_LIB|'${plfs_instdir}'/lib|;s|REPLACE_PLFS_INC|'${plfs_instdir}'/include|' \
    ${platform_file} > ./platform_file
check_exit $? "Generating platform file for openmpi"

# Run configure
echo "Running configure script with --prefix=$openmpi_instdir"
./configure --prefix=$openmpi_instdir --with-platform=./platform_file
check_exit $? "Configure process"

# Run make
echo "Running make"
make
check_exit $? "Make process"

# Run make install
echo "Running make install"
make install
check_exit $? "Make install process"

echo "Building and installing openmpi completed."
