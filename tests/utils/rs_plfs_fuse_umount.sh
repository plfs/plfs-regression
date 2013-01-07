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
# This script is used to unmount plfs from mountpoints using executables from
# the regression suite. It uses scripts in the plfs installation and the
# utilities module in the ioandnetworking repository.
#
# The return values are 0 or 1:
#
# 0: Mount points are unmounted as of when the script exits.
# 1: Mount points are still mounted (at least one in the case of parallel)
#    as of when the script exits.

# We need to figure out where this script is located. It should be in a 
# regression suite directory tree.
# Figure out the absolute directory name of where this script is located.
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# May as well get the script's name, too.
script_name="$( basename "${BASH_SOURCE[0]}" )"

function Usage {
    echo "Usage:"
    echo "$script_name MOUNT [serial]"
    echo ""
    echo "MOUNT is the mount point that needs to be unmounted."
    echo "serial is an optional parameter that will tell this script to unmount"
    echo "MOUNT only on the current host."
}

# Get the location of the base regression directory
basedir=`echo $script_dir | sed 's|tests/utils.*||'`

if [ "$basedir" == "" ]; then
    echo "$script_name Error: Unable to determine the base directory to the regression suite."
    echo "This script should be located somewhere below the regression/tests directory."
    exit 1
fi

if [[ $# < 1 ]]; then
    echo "$script_name Error: Insufficient number of command line parameters"
    Usage
    exit 1
fi

mount_point=$1
serial="False"

if [ -n "$2" ]; then
    if [ "$2" == "serial" ]; then
        serial="True"
    else
        echo "$script_name Error: Invalid command line parameter $2"
        Usage
        exit 1
    fi
fi

test_cmd="grep Uptime ${mount_point}/.plfsdebug >> /dev/null 2>&1"

successfully_umounted="False"

if [ "$serial" == "True" ]; then #Serial
    echo "$script_name: Attempting to unmount $mount_point"
    fusermount -u $mount_point 
    # check to make sure it is no longer mounted
    eval $test_cmd
    if [ $? != 0 ]; then
        successfully_unmounted="True"
    else
        successfully_unmounted="False"
    fi
else # parallel
    echo "$script_name: Attempting to unmount $mount_point on all nodes"
    ${basedir}/tests/utils/rs_computenodes_plfs_launch.csh --plfs=${basedir}/inst/plfs/sbin/plfs --pexec=${basedir}/tests/utils/pexec.pl --mntpt=$mount_point umount
    ret=$?
    if [ $ret == 0 ]; then
        successfully_unmounted="True"
    else
        successfully_unmounted="False"
    fi
fi

if [ "$successfully_unmounted" == "True" ]; then
    echo "$script_name: unmounting successful"
    exit 0
else
    echo "$script_name Error: unmounting unsuccessful"
    exit 1
fi
