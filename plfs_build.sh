#!/bin/bash -l
#
###################################################################################
# Copyright (c) 2009, Los Alamos National Security, LLC All rights reserved.
# Copyright 2009. Los Alamos National Security, LLC. This software was produced
# under U.S. Government contract DE-AC52-06NA25396 for Los Alamos National
# Laboratory (LANL), which is operated by Los Alamos National Security, LLC for
# the U.S. Department of Energy. The U.S. Government has rights to use,
# reproduce, and distribute this software.  NEITHER THE GOVERNMENT NOR LOS
# ALAMOS NATIONAL SECURITY, LLC MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR
# ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.  If software is
# modified to produce derivative works, such modified software should be
# clearly marked, so as not to confuse it with the version available from
# LANL.
# 
# Additionally, redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following conditions are
# met:
# 
#    Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
#    Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 
#    Neither the name of Los Alamos National Security, LLC, Los Alamos National
# Laboratory, LANL, the U.S. Government, nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY LOS ALAMOS NATIONAL SECURITY, LLC AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL LOS ALAMOS NATIONAL SECURITY, LLC OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
###################################################################################
#
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

# See if we need to clean out a previous compilation attempt. We want to start
# over completely from the configure step.
if [ -e Makefile ]; then
    echo "Compilation seems to have been attempted in the plfs source directory already. Running 'make clean'."
    make clean
fi

echo "Running cmake"
cmake . -DCMAKE_INSTALL_PREFIX:PATH=$instdir

check_exit $? "cmake process"

echo "Running make"
make VERBOSE=1
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
