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
# This is the regression suite's (rs) environment setup script for tests.
# Call this script on the compute nodes to make sure the proper environment
# is set up to actually run the test within the regression framework on
# a particular machine.
#
# Input:
# For ease of use, pass the regression suite's base directory on the command
# line. This will make it easier to find other scripts to source in the utils
# directory.

function print_usage {
    echo "Usage:"
    echo "rs_env_init.sh"
    echo ""
}

# Figure out where we are. The following three lines will figure out the
# directory name even if this script is sourced, is a sym link, pretty
# much anything.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
ab_dir="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
# May as well get the scripts's name, too.
script_name="$( basename "$SOURCE" )"

basedir=`echo $ab_dir | sed 's|/tests/utils.*||'`
if [ "$basedir" == "" ]; then
    echo "$script_name Error: Unable to determine the base directory to the regression suite."
    echo "This script should be located somewhere below the tests/utils directory."
    exit 1
else
    echo "$script_name: Using $basedir as the base directory for the regression suite."
fi

PATH=$basedir/inst/plfs/sbin:$basedir/inst/plfs/bin:$basedir/inst/mpi/bin:$PATH
export PATH

# Some MPI implementations require their lib directory to be in LD_LIBRAY_PATH,
# so we'll always put it in.
LD_LIBRARY_PATH=$basedir/inst/mpi/lib:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH

# Get the tests/utils directory
utils_dir="$basedir/tests/utils"

# Source a personal customization script, if it exists
customize="${utils_dir}/env_customize.sh"
if [ -f "$customize" ]; then
    echo "Sourcing $customize"
    source $customize
fi
