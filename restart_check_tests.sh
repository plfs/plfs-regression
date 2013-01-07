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
# Without this, there is a spurious "TERM environment variable not
# set" message when cron runs this script.
export TERM=dumb

# Source the configuration file. It must be in the same directory as this
# executable
exec_dir=`dirname $0`
if [ -e "${exec_dir}/config" ]; then
    source ${exec_dir}/config
else
    echo "run_plfs_regression.sh error: config file not present. Exiting." 1>&2
    exit 1
fi

# Check that anything in the regression environment can be run
if [ -e "${basedir}/DO_NOT_RUN_REGRESSION" ]; then
    echo "DO_NOT_RUN_REGRESSION file present."
    exit 0
fi

# Check to see if a regression session is being run right now.
if [ -e "${id_file}" ]; then
    echo "$id_file is present... previous regression session is running."

    # Check to see if run_plfs_regression.sh is still running
    if [ -e "${run_plfs_regression_lock}" ]; then
        echo "$run_plfs_regression_lock exists, run_plfs_regression.sh still running."
        echo "No need to restart check_tests.py"
    else
    
        # Check if check_tests.py is already running
        stat=`ps aux | grep "python.*check_tests.py" | grep -v grep`
        if [ -z "$stat" ]; then
            # Restart check_tests.py
            echo "Id file $id_file present, but check_tests.py is not running. Restarting it." 1>&2
            ${basedir}/check_tests.py --dictfile=$dict_file --idfile=$id_file \
            --emailaddr=$addr --emailmsginc=$email_message \
            --logfile=$check_tests_log --logfile_mode=a --basedir=$basedir &
        else
            echo "check_tests.py already running. No need to restart check_tests.py."
        fi
    fi
else
    echo "No regression session is currently being run. No need to restart check_tests.py."
fi
exit 0
