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

# I assume that the top-level directory in the openmpi tarball is the same as
# the tarball's name without ".tar.bz2". I also assume that the tarball is
# named as follows: openmpi-<version>.tar.bz2 where version contains only
# digits and decimal points like this: 1.6.0 or 1.5, etc.

# Get the basename of the openmpi tarball, then figure out what name
# the directory will be when unarchived.
openmpi_name=`basename $tarball | sed 's/\.tar.*$//'`
# Figure out the version of openmpi from openmpi_name
version=${openmpi_name#openmpi-}

# Function to check the exit status of the last command
function check_exit {
    if [[ $1 == 0 ]]; then
        echo "$2 succeeded."
    else
        echo "Error: $2 failed."
        exit 1
    fi
}

# Function to find a patch file in the plfs source tree that is suitable for a
# given version of Open MPI. It will modify the variable PATCH_FILE so that the
# result can be easily used by the calling process. This function prints out
# messages as it works, so capturing its stdout isn't enough to get the patch
# file.
#
# Since a single patch file can cover several versions of Open MPI
# (signified by the use of an x in the version string in the patch file name),
# we have to figure out which patch file can be used with the given version of
# Open MPI.
#
# Usage:
# find_patchfile VER
#
# Input:
# - VER: version of Open MPI that we are working with.
#
# Return values:
# - 0: Suitable patch file found successfully
# - 1: Suitable patch file not found
#
# Output:
# - various status messages to stdout
# - PATCH_FILE: this variable will possibly contain, after executing this
#   function, a path to a suitable patch file. The path will be relative to the
#   plfs source directory. This variable should be set before calling this
#   function and then can be used after this function returns. It is not
#   initialized by this function and will not modify it if a suitable patch is
#   not found.
function find_patchfile {
    ver=$1
    patches_dir="patches/openmpi"

    i=0
    # Check for a ompi-<version>-plfs-prep.patch file. Then, iterate up the
    # periods in the version string to see if a patch that works for more than
    # one version is found. For example, if the version string is 4.5.6, look
    # for 4.5.6.patch, 4.5.x.patch, and 4.x.patch
    # First, put the digits in the version variable into an array so that each
    # digit can be treated separately. Each digit will be a token.
    old_IFS=$IFS
    IFS="."
    ver_toks=( $ver )
    IFS=$old_IFS
    # Get the number of digits
    num_toks=${#ver_toks[*]}
    # There are num_toks - 1 possible strings to construct from the version
    # number. Loop over them.
    while [ $i -lt $num_toks ]; do
        string=""
        j=0
        # Construct a version string from ver_toks
        while [ $j -lt $(($num_toks - $i)) ]; do
            string="${string}${ver_toks[$j]}"
            j=$(($j + 1))
            if [ ! $j -eq $(($num_toks - $i)) ]; then
                string="${string}."
            fi
        done
        # If i is 0, then all of the tokens are in string. Don't add a .x
        # place holder for this case. For all other values of i, there is at least
        # one token missing, so a .x needs to be appended.
        if [ ! $i -eq 0 ]; then
            string="${string}.x"
        fi
        tfile="${patches_dir}/ompi-${string}-plfs-prep.patch"
        echo -n "Checking for $tfile..."
        if [ -e "$tfile" ]; then
            echo "found"
            PATCH_FILE=$tfile
            break
        else
            echo "not found"
        fi
        i=$(($i + 1))
    done

    # If a suitable patch file hasn't been found, check down the version
    # string for either a 0 or an x. For example, if the version
    # string is 6.1, look for 6.1.0.patch and 6.1.x.patch. Keeping going
    # down levels until files don't exist with more .0 in the string. For
    # exmaple, if the version string is 6.1 and 6.1.[0|x].patch doesn't exist,
    # but ls on 6.1.0*.patch returns filenames, check for 6.1.0.0.patch and
    # 6.1.0.x.patch. Keep going until tacking on another .0 to the version
    # fails to find any files via ls.
    if [ "$PATCH_FILE" == "" ]; then
        cver=$ver
        while [ 1 ]; do
            # Check for $cver.0.patch and $cver.x.patch
            for tfile in ${patches_dir}/ompi-${cver}.0-plfs-prep.patch \
                ${patches_dir}/ompi-${cver}.x-plfs-prep.patch; do
                echo -n "Checking for $tfile..."
                if [ -e "$tfile" ]; then
                    echo "found"
                    PATCH_FILE=$tfile
                    break
                else
                    echo "not found"
                fi
            done
            # If we didn't find it, check to see if 
            # ad-patches/openmpi/*cver.0* exists. If so, reset cver and try again.
            # If not, break out of the while loop.
            if [ "$PATCH_FILE" == "" ]; then
                ls -1 ${patches_dir} | grep ${cver}.0 2>&1 >> /dev/null
                if [[ $? == 0 ]]; then
                    cver="${cver}.0"
                else
                    break
                fi
            else
                # A patch file was found in the last for loop. Break out of the
                # while loop.
                break
            fi
        done
    fi

    # Check to see if we found a patch file
    if [ "$PATCH_FILE" != "" ]; then
        echo "Using $PATCH_FILE"
    else
        echo "Suitable patch file not found."
        return 1
    fi
    return 0
}

# Go to the plfs source directory
echo "Entering $plfs_srcdir/mpi_adio"
if [ ! -d "$plfs_srcdir/mpi_adio" ]; then
    echo "Error: $plfs_srcdir/mpi_adio does not exist."
    exit 1
fi
cd "$plfs_srcdir/mpi_adio"

# Run the make_plfs_patch script to generate ompi-plfs.patch. Capture the
# output to figure out what the name of the generated patch file is.
echo "Running ./scripts/make_plfs_patch"
./scripts/make_ad_plfs_patch | tee ./.mk_plfs_ptch_output_file
ad_plfs_patch_file=`tail -n 1 ./.mk_plfs_ptch_output_file | awk '{print $NF}'`
rm -f ./.mk_plfs_ptch_output_file
# Check that the patch file exists and is not size zero.
if [ ! -f "$ad_plfs_patch_file" ] || [ ! -s "$ad_plfs_patch_file" ]; then
    echo "Problem generating patch file."
    exit 1
fi

# We need to figure out what prep.patch file to use for this version of Open
# MPI. The find_patchfile function will do this. It will modify the following
# variable, PATCH_FILE, to be the file that we need.
PATCH_FILE=""
find_patchfile $version
if [[ $? != 0 ]]; then
    exit 1
fi

# If we're here, all the needed patch stuff is found, so we can get started
# building openmpi

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

# Change directory to the open mpi source directory
echo "Entering ${srcdir}/${openmpi_name}"
if [ ! -d "${srcdir}/${openmpi_name}" ]; then
    echo "Error: ${srcdir}/${openmpi_name} directory not found"
    exit 1
fi
cd ${srcdir}/${openmpi_name}

# Patch Open MPI
echo "Patching Open MPI..."
patch -p1 < ${plfs_srcdir}/mpi_adio/${PATCH_FILE}
check_exit $? "Using ${plfs_srcdir}/${PATCH_FILE}"
patch -p1 < ${ad_plfs_patch_file}
check_exit $? "Using ${ad_plfs_patch_file}"

# Run autogen.sh
echo "Running ./autogen.sh"
./autogen.sh
check_exit $? "Autogen.sh process"

# Get the platform file from the plfs source directory, substituting the right
# paths for the regression environment.
echo "Generating platform file for openmpi compilation"
sed 's|REPLACE_PLFS_LIB|'${plfs_instdir}'/lib|g;s|REPLACE_PLFS_INC|'${plfs_instdir}'/include|g' \
    ${platform_file} > ./platform_file
check_exit $? "Generating platform file for openmpi"

# Run configure
echo "Running configure script with --prefix=$openmpi_instdir"
./configure --prefix=$openmpi_instdir --with-platform=./platform_file
check_exit $? "Configure process"

# Run make
echo "Running make"
make -j 3
check_exit $? "Make process"

# Run make install
echo "Running make install"
make install
check_exit $? "Make install process"

echo "Building and installing openmpi completed."
