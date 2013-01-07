#!/bin/bash
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
