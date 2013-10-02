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
# This is the main script that starts a plfs regression run.
# It will check out or copy all needed pieces of code and then build the
# appropriate ones. It will call on a script to submit jobs if all the 
# needed coded compiled. It will then pass control over to the script
# that will monitor running tests. Only if there is a problem with getting
# source code, building it, or passing control to the next script will this
# script send a report.

# Source the configuration file. It must be in the same directory as this
# executable
exec_dir=`dirname $0`
if [ -e "${exec_dir}/config" ]; then
    source ${exec_dir}/config
else
    echo "run_plfs_regression.sh error: config file not present. Exiting." 1>&2
    exit 1
fi

# Since the regression will be run on multiple machines, we'll need
# to know where this particular instance was run.
host=$HOSTNAME

# Without this, there is a spurious "TERM environment variable not
# set" message when cron runs this script.
export TERM=dumb

function print_usage {
    echo "$0 usage:"
    echo "$0 [OPTION ...]"
    echo ""
    echo "OPTIONS"
    echo -e "\t--plfssrc=DIR"
    echo -e "\t\tEquivalent to setting plfs_source_directory in the config file."
    echo -e "\t--openmpitar=FILE"
    echo -e "\t\tEquivalent to setting open_mpi_tarball in the config file."
    echo -e "\t--fstestsrc=DIR"
    echo -e "\t\tEquivalent to setting fs_test_source in the config file."
    echo -e "\t--utilitiessrc=DIR"
    echo -e "\t\tEquivalent to setting utilities_source in the config file."
    echo -e "\t--exprmgmtsrc=DIR"
    echo -e "\t\tEquivalent to setting experiment_management_source in the config file."
    echo -e "\t--testtypes=LIST"
    echo -e "\t\tEquivalent to setting test_types in the config file."
    echo -e "\t--nodelete"
    echo -e "\t\tEquivalent to setting delete_passing_test_output to False in the config file."
    echo -e "\t--nobuild"
    echo -e "\t\tEquivalent to setting do_building to False in the config file."
    echo -e "\t--notests"
    echo -e "\t\tEquivalent to setting do_tests to False in the config file."
    echo -e "\t--noemail"
    echo -e "\t\tEquivalent to setting send_email to False in the config file."
    echo -e "\t--noprompt"
    echo -e "\t\tEquivalent to setting prompt to False in the config file."
    echo -e "\t-h,--help"
    echo -e "\t\tDisplay this message and exit"
}

# Function that will format an email message detailing a summary of
# tasks done and the tasks' status. Will put that summary in a file
# defined by the email_message variable in plfsregrc.
function format_email {
    echo "Regression date:" `date +%F` > $email_message
    echo "Summary of regression steps:" >> $email_message
    echo "" >> $email_message

    # Check plfs
    echo "PLFS status....$plfs_ok: $plfs_stat" >> $email_message
    if [ "$plfs_ok" == "FAIL" ]; then
        echo "Log file located at $plfs_build_log" >> $email_message
    fi

    # Check mpi 
    echo "MPI status...$mpi_ok: $mpi_stat" >> $email_message
    if [ "$mpi_ok" == "FAIL" ]; then
        echo "Log file located at $mpi_build_log" >> $email_message
    fi

    # Check fs_test
    echo "fs_test status....$fs_test_ok: $fs_test_stat" >> $email_message
    if [ "$fs_test_ok" == "FAIL" ]; then
        echo "Log file located at $fs_test_build_log" >> $email_message
    fi

    # Check getting experiment_management
    echo "experiment_management status...$expr_mgmt_ok: $expr_mgmt_stat" >> $email_message
    if [ "$expr_mgmt_ok" == 'FAIL' ]; then
        echo "Log file located at $expr_mgmt_get_log" >> $email_message
    fi

    # Check rc config files
    echo "rc config files...$config_file_ok: $config_file_stat" >> $email_message
    if [ "$config_file_ok" == "FAIL" ]; then
        echo "Log file located at $config_file_log" >> $email_message
    fi

    echo "" >> $email_message

    # Check if submitting tests worked  
    if [ "$runtests" == "True" ]; then
        echo "Submitting tests...$submit_test_stat" >> $email_message
        if [ "$submit_test_stat" != 'PASS' ]; then
            echo "Please see $submit_tests_log." >> $email_message
        fi
    else
        echo "--notests used. No jobs submitted." >> $email_message
    fi
}

# Function that can be used to send an email message about a regression run.
# Pulls many of the needed variables from plfsregrc.
#
# Input:
# - String to describe if the regression run passed or failed. This will be
#   used in the subject line of the email message so that it is easy to determine
#   if the regression run failed.
function send_email {
    subj="PLFS regression on $host: $1"
    /bin/mail -s "$subj" $addr < $email_message
    rm -f $email_message
}

# Function to exit when not passing control to check_tests.py. Removes the lock file
# and calls send_email if need be.
#
# Usage:
# script_exit_no_pass <status> <return value>
#
# <status> is FAILED or PASSED that will be passed to send_email
# <return value> is what will be passed to the system's exit call.
function script_exit_no_pass {
    if [ $doemail == "True" ]; then
        send_email $1
    fi
    rm -rf $id_file
    rm -f $run_plfs_regression_lock
    exit $2
}

# Function to exit from this script. Based on the single command line parameter
# passed to it, it will exit or pass control to check_tests.py.
#
# Input is a single integer: 
# If $1 is a 0, everything went fine so pass control to check_tests.py before exiting.
# If $1 is something else, there was a problem and the regression run should stop
# without passing control to check_tests.py.
function script_exit {
    if [ $doemail == "True" ]; then
        format_email
    fi

    if [ $1 == "0" ]; then
        if [ $runtests == "True" ]; then
            echo "Passing control to check_tests.py and exiting."
            echo "Please see $check_tests_log."
            if [ $doemail == "True" ]; then
                ${basedir}/check_tests.py --dictfile=$dict_file --idfile=$id_file \
                --emailaddr=$addr --emailmsginc=$email_message \
                --logfile=$check_tests_log --basedir=$basedir $nodelete &
            else
                ${basedir}/check_tests.py --dictfile=$dict_file --idfile=$id_file \
                --logfile=$check_tests_log --basedir=$basedir $nodelete --noemail &
            fi
        else
            echo "--notests used...control will not be passed to check_tests.py"
            script_exit_no_pass PASSED $1
        fi
    else
        echo "Regression run FAILED"
        echo "Since no tests were submitted, control will not be passed to"
        echo "check_tests.py."
        script_exit_no_pass FAILED $1
    fi
    # Regular exit. Remove this script's lock file and exit.
    rm -f $run_plfs_regression_lock
    exit $1
}

# Function that will set up environment variables for building against PLFS.
#
# No input and no output, but after calling the function, AD_PLFS_LDFLAGS and
# AD_PLFS_CFLAGS environment variables will be set for linking and compiling
# against PLFS. AD_PLFS_LDFLAGS will contain the necessary linking flags;
# AD_PLFS_CFLAGS will contain the necessary compling flags.
function setup_rs_plfs_flags {
    # Grab the flags needed for building against PLFS
    flags=`tests/utils/rs_plfs_buildflags_get.py`
    if [[ $? != 0 ]]; then
        return 1
    fi
    rs_plfs_cflags=`echo "$flags" | head -n 1`
    rs_plfs_ldflags=`echo "$flags" | tail -n 1`
    export AD_PLFS_LDFLAGS=$rs_plfs_ldflags
    export AD_PLFS_CFLAGS=$rs_plfs_cflags
}

function check_env_vars {
    env_var_problem="False"
    if [ -z "$MPI_CC" ]; then
        echo "MPI_CC env variable not set"
        env_var_problem="True"
    fi
    if [ -z "$MY_MPI_HOST" ]; then
        echo "MY_MPI_HOST env variable not set"
        env_var_problem="True"
    fi
    if [ "$env_var_problem" == "True" ]; then
        return 1
    else
        return 0
    fi
}

# Default values for control variables.
plfs_src_from="None"
plfs_bin_dir="None"
plfs_sbin_dir="None"
plfs_lib_dir="None"
plfs_inc_dir="None"
plfs_src_dir="None"
openmpi_tarball="None"
mpi_bin_dir="None"
mpi_lib_dir="None"
mpi_inc_dir="None"
fs_test_src_from="None"
fs_test_loc="None"
expr_mgmt_src_from="None"
expr_mgmt_loc="None"
testtypes="1,2"
nodelete=""
build="True"
runtests="True"
doemail="True"
prompt_user="True"

# The config file has already been parsed, so check command line args.
for i in $*
do
    case $i in
        --plfssrc=*)
            plfs_source_directory=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
            ;;
        --fstestsrc=*)
            fs_test_source_directory=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
            ;;
        --exprmgmtsrc=*)
            experiment_management_source=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
            ;;
        --openmpitar=*)
            open_mpi_tarball=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
            ;;
        --testtypes=*)
            test_types=`echo $i | sed 's/[-a-zA-Z0-9]*=//'`
            ;;
        --nodelete)
            delete_passing_test_output="False"
            ;;
        "-h" | "--help")
            print_usage
            exit 0
            ;;
        --nobuild)
            do_building="False"
            ;;
        --notests)
            do_tests="False"
            ;;
        --noemail)
            send_email="False"
            ;;
        --noprompt)
            prompt="False"
            ;;
        *)
            # Unknown option
            echo "$0: Unknown command line option $i"
            print_usage
            exit 1
            ;;
    esac
done

# Check if any parameters where set in the config file
if [ -n "$plfs_source_directory" ]; then
    if [ -d "$plfs_source_directory" ]; then
        plfs_src_from="$plfs_source_directory"
    else
        echo "$0: $plfs_source_directory is not a valid directory."
        exit 1
    fi
elif [ -n "$plfs_bin_directory" ] && [ -n "$plfs_sbin_directory" ] && [ -n "$plfs_lib_directory" ] && [ -n "$plfs_include_directory" ] && [ -n "$plfs_src_directory" ]; then
    plfs_bin_dir="$plfs_bin_directory"
    if [ ! -d "$plfs_bin_directory" ]; then
        echo "$0: $plfs_bin_dir is not a valid directory."
        exit 1
    fi
    plfs_sbin_dir="$plfs_sbin_directory"
    if [ ! -d "$plfs_sbin_directory" ]; then
        echo "$0: $plfs_sbin_dir is not a valid directory."
        exit 1
    fi
    plfs_lib_dir="$plfs_lib_directory"
    if [ ! -d "$plfs_lib_dir" ]; then
        echo "$0: $plfs_lib_dir is not a valid directory."
        exit 1
    fi
    plfs_inc_dir="$plfs_include_directory"
    if [ ! -d "$plfs_inc_dir" ]; then
        echo "$0: $plfs_inc_dir is not a valid directory."
        exit 1
    fi
    plfs_src_dir="$plfs_src_directory"
    if [ ! -d "$plfs_src_dir" ]; then
        echo "$0: $plfs_src_dir is not a valid directory."
        exit 1
    fi
else
    echo "$0: either plfs_source_directory or plfs_bin_directory, plfs_sbin_directory, plfs_lib_directory, plfs_include_directory and plfs_src_directory must be specified. Please see the config file."
    exit 1
fi

if [ -n "$open_mpi_tarball" ]; then
    if [ -f "$open_mpi_tarball" ]; then
        openmpi_tarball="$open_mpi_tarball"
        # Check the platform file
        if [ -f "$basedir/openmpi_platform_file" ]; then
            ompi_platform_file=$basedir/openmpi_platform_file
        elif [ -f "$basedir/openmpi_platform_file.sample" ]; then
            ompi_platform_file=$basedir/openmpi_platform_file.sample
        else
            echo "$0: neither openmpi_platform_file or openmpi_platform_file.sample are present for correctly building openmpi."
            exit 1
        fi
    else
        echo "$0: $open_mpi_tarball is not a valid file."
        exit 1
    fi
elif [ -n "$mpi_bin_directory" ] && [ -n "$mpi_lib_directory" ] && [ -n "$mpi_include_directory" ]; then
    mpi_bin_dir="$mpi_bin_directory"
    if [ ! -d "$mpi_bin_dir" ]; then
        echo "$0: $mpi_bin_dir is not a valid directory."
        exit 1
    fi
    mpi_lib_dir="$mpi_lib_directory"
    if [ ! -d "$mpi_lib_dir" ]; then
        echo "$0: $mpi_lib_dir is not a valid directory."
        exit 1
    fi
    mpi_inc_dir="$mpi_include_directory"
    if [ ! -d "$mpi_inc_dir" ]; then
        echo "$0: $mpi_inc_dir is not a valid directory."
        exit 1
    fi
else
    echo "$0: either open_mpi_tarball or mpi_bin_directory, mpi_lib_directory and mpi_include_directory must be specified. Plese see the config file."
    exit 1
fi

if [ -n "$fs_test_source_directory" ]; then
    if [ -d "$fs_test_source_directory" ]; then
        fs_test_src_from="$fs_test_source_directory"
    else
        echo "$0: $fs_test_source is not a valid directory"
        exit 1
    fi
elif [ -n "$fs_test_location" ]; then
    if [ -e "$fs_test_location" ]; then
        fs_test_loc=$fs_test_location
    else
        echo "$0: $fs_test_location is not a valid executable."
        exit 1
    fi
else
    echo "$0: either fs_test_source_directory or fs_test_location must be specified. Please see the config file."
    exit 1
fi

if [ -n "$experiment_management_source" ]; then
    if [ -d "$experiment_management_source" ]; then
        expr_mgmt_src_from="$experiment_management_source"
    else
        echo "$0: $experiment_management_source is not a valid directory"
        exit 1
    fi
elif [ -n "$experiment_management_directory" ]; then
    if [ -d "$experiment_management_directory" ]; then
        expr_mgmt_loc=$experiment_management_directory
    else
        echo "$0: $experiment_management_directory is not a valid directory."
        exit 1
    fi
else
    echo "$0: either experiment_management_source or experiment_management_directory must be specified. Please see the config file."
    exit 1
fi

if [ -n "$test_types" ]; then
    testtypes="$test_types"
fi

if [ -n "$delete_passing_test_output" ]; then
    if [ "$delete_passing_test_output" == "True" ]; then
        nodelete=""
    elif [ "$delete_passing_test_output" == "False" ]; then
        nodelete="--nodelete"
    else
        echo "$0: Invalid option for delete_passing_test_output. Must be True or False. Please see the config file."
        exit 1
    fi
fi

if [ -n "$do_building" ]; then
    if [ "$do_building" == "True" ]; then
        build="True"
    elif [ "$do_building" == "False" ]; then
        build="False"
    else
        echo "$0: Invalid option for do_building. Must be True or False. Please see the config file."
        exit 1
    fi
fi

if [ -n "$do_tests" ]; then
    if [ "$do_tests" == "True" ]; then
        runtests="True"
    elif [ "$do_tests" == "False" ]; then
        runtests="False"
    else
        echo "$0: Invalid option for do_tests. Must be True or False. Please see the config file."
        exit 1
    fi
fi

if [ -n "$send_email" ]; then
    if [ "$send_email" == "True" ]; then
        doemail="True"
    elif [ "$send_email" == "False" ]; then
        doemail="False"
    else
        echo "$0: Invalid option for send_email. Must be True or False. Please see the config file."
        exit 1
    fi
fi

if [ -n "$prompt" ]; then
    if [ "$prompt" == "True" ]; then
        prompt_user="True"
    elif [ "$prompt" == "False" ]; then
        prompt_user="False"
    else
        echo "$0: Invalid option for prompt. Must be True or False. Please see the config file."
        exit 1
    fi
fi

# If we're here, then we need to attempt to do a regression run of some sort.
# Check that this instance of the regression can and/or should run
if [ -e "${basedir}/DO_NOT_RUN_REGRESSION" ]; then
    echo "DO_NOT_RUN_REGRESSION file present. This instance of a" 1>&2
    echo "regression run will now exit." 1>&2
    exit 0
fi

if [ -e "${id_file}" ]; then
    echo "Previous regression instance still running. Exiting." 1>&2
    exit 0
fi

check_env_vars
if [[ $? != 0 ]]; then
    exit 1
fi

# Print some info about where stuff is coming from and what will be attempted.
echo "Info for this regression run:"
echo ""
if [ "$plfs_src_from" == "None" ]; then
    echo "Using PLFS from the following locations:"
    echo "PLFS user binaries: $plfs_bin_dir"
    echo "PLFS admin binaries: $plfs_sbin_dir"
    echo "PLFS libraries: $plfs_lib_dir"
    echo "PLFS headers: $plfs_inc_dir"
    echo "PLFS source: $plfs_src_dir"
else
    echo "PLFS source: $plfs_src_from"
fi
if [ "$openmpi_tarball" == "None" ]; then
    echo "Using MPI from the following locations:"
    echo "MPI binaries: $mpi_bin_dir"
    echo "MPI libraries: $mpi_lib_dir"
    echo "MPI headers: $mpi_inc_dir"
else
    echo "Open MPI source: $openmpi_tarball"
    echo "Open MPI platform file: $ompi_platform_file"
fi
if [ "$fs_test_src_from" == "None" ]; then
    echo "fs_test binary: $fs_test_loc"
else
    echo "fs_test source: $fs_test_src_from"
fi
if [ "$expr_mgmt_src_from" == "None" ]; then
    echo "Experiment_management location: $expr_mgmt_loc"
else
    echo "experiment_management source: $expr_mgmt_src_from"
fi

echo "MY_MPI_HOST: $MY_MPI_HOST"
echo "MPI_CC: $MPI_CC"
echo "Test types: $testtypes"
echo "Building: $build"
echo "Sending email: $doemail"
echo "Running and checking tests: $runtests"
if [ "$nodelete" == "" ]; then
    echo "Delete output of passed tests: True"
else
    echo "Delete output of passed tests: False"
fi
echo ""

if [ "$prompt_user" == "True" ]; then
    read -sn 1 -p "Ready to begin regression run. Press any key to continue..."; echo
fi

# Create the lock file id_file
touch $id_file

# Create a lock file for just run_plfs_regression
touch $run_plfs_regression_lock

# Variables to keep track of what gets done.
plfs_stat="Not checked"
plfs_ok="PASS"
mpi_stat="Not checked"
mpi_ok="PASS"
fs_test_stat="Not checked"
fs_test_ok="PASS"
expr_mgmt_stat="Not checked"
expr_mgmt_ok="PASS"
submit_test_stat="Not done"
config_file_stat="Not checked"
config_file_ok="PASS"

# Log files
log_dir=$basedir/logs
# Make the directory if need be.
if [ ! -d "$log_dir" ]; then
    if [ -e "$log_dir" ]; then
        echo "Error: logs exists but not as a directory. Exiting." 1>&2
        script_exit 1
    fi
    mkdir $log_dir
fi

# make sure the source directory exists
if [ ! -d "$srcdir" ]; then
    if [ -e "$srcdir" ]; then
        echo "Error: $srcdir exists but not as a directory. Exiting." 1>&2
        script_exit 1
    fi
    mkdir $srcdir
    if [[ $? != 0 ]]; then
        echo "Error: unable to create $srcdir. Exiting." 1>&2
        script_exit 1
    fi
fi

# make sure the install directory exists
if [ ! -d "$instdir" ]; then
    if [ -e "$instdir" ]; then
        echo "Error: $instdir exists but not as a directory. Exiting." 1>&2
        script_exit 1
    fi
    mkdir $instdir
    if [[ $? != 0 ]]; then
        echo "Error: unable to create $instdir. Exiting." 1>&2
        script_exit 1
    fi
fi

# Specify all the different log files.
plfs_build_log=${log_dir}/plfs_build.log
mpi_build_log=${log_dir}/mpi_build.log
fs_test_build_log=${log_dir}/fs_test_build.log
expr_mgmt_get_log=${log_dir}/expr_mgmt_get.log
submit_tests_log=${log_dir}/submit_tests.log
config_file_log=${log_dir}/config_file.log

# Get and build what we need
if [ "$build" == "True" ]; then
    # PLFS
    echo "Checking PLFS. Please see $plfs_build_log."
    if [ "$plfs_src_from" == "None" ]; then
        # Using an already defined plfs installation. plfs_bin_dir,
        # plfs_lib_dir, plfs_inc_dir and plfs_src_dir will already be defined.

        echo "Linking plfs..." | tee $plfs_build_log
        # Check for a user binary
        if [ -e "$plfs_bin_dir/plfs_check_config" ]; then
            echo "Found $plfs_bin_dir/plfs_check_config" >> $plfs_build_log
        else
            echo "$plfs_bin_dir/plfs_check_config not found. It does not appear that $plfs_bin_dir contains plfs binaries." >> $plfs_build_log
            plfs_stat="plfs binaries not found"
            plfs_ok="FAIL"
        fi
        # Check for a admin binary
        if [ -e "$plfs_sbin_dir/plfs" ]; then
            echo "Found $plfs_sbin_dir/plfs" >> $plfs_build_log
        else
            echo "$plfs_sbin_dir/plfs. It does not appear that $plfs_sbin_dir contains plfs admin binaries." >> $plfs_build_log
            plfs_stat="plfs binaries not found"
            plfs_ok="FAIL"
        fi
        # Check for libplfs
        ls $plfs_lib_dir | grep -q libplfs
        if [[ $? == 0 ]]; then
            # Found a libplfs
            echo "Found a libplfs in $plfs_lib_dir" >> $plfs_build_log
        else
            echo "libplfs* was not found in $plfs_lib_dir. It does not appear that $plfs_lib_dir contains plfs libraries." >> $plfs_build_log
            plfs_stat="plfs libraries not found"
            plfs_ok="FAIL"
        fi
        # Check for plfs headers
        if [ -e "$plfs_inc_dir/plfs.h" ]; then
            echo "Found $plfs_inc_dir/plfs.h" >> $plfs_build_log
        else
            echo "$plfs_inc_dir does not contain a plfs.h. It does not appear that $plfs_inc_dir contains plfs headers." >> $plfs_build_log
            plfs_stat="plfs headers not found"
            plfs_ok="FAIL"
        fi
        # Check for plfs source
        if [ -e "$plfs_src_dir/mpi_adio/scripts/make_ad_plfs_patch" ]; then
            echo "Found plfs source in $plfs_src_dir" >> $plfs_build_log
        else
            echo "$plfs_src_dir does not contain mpi_adio/scripts/make_ad_plfs_patch. It does not appear that $plfs_src_dir contains plfs source files." >> $plfs_build_log
            plfs_stat="plfs source not found"
            plfs_ok="FAIL"
        fi
        if [ "$plfs_ok" == "PASS" ]; then
            # If we're here, plfs has been successfully found. Link it in to
            # the regression suite so tests can know where to always find it.
            plfs_stat="plfs successfully found"
            if [ -d "${instdir}/plfs" ]; then
                rm -rf "${instdir}/plfs" >> $plfs_build_log 2>&1
                if [ -d "${instdir}/plfs" ]; then
                    plfs_stat="unable to remove old plfs installation"
                    plfs_ok="FAIL"
                fi
            fi
            if [ -d "${srcdir}/plfs" ]; then
                rm -rf "${srcdir}/plfs" >> $plfs_build_log 2>&1
                if [ -d "${srcdir}/plfs" ]; then
                    plfs_stat="unable to remove old plfs source directory"
                    plfs_ok="FAIL"
                fi
            fi
            if [ "$plfs_ok" == "PASS" ]; then
                mkdir ${instdir}/plfs
                if [[ $? == 0 ]]; then
                    echo "Linking..." >> $plfs_build_log
                    ln -s $plfs_bin_dir ${instdir}/plfs/bin >> $plfs_build_log 2>&1 && \
                        ln -s $plfs_sbin_dir ${instdir}/plfs/sbin >> $plfs_build_log 2>&1 && \
                        ln -s $plfs_lib_dir ${instdir}/plfs/lib >> $plfs_build_log 2>&1 && \
                        ln -s $plfs_inc_dir ${instdir}/plfs/include >> $plfs_build_log 2>&1
                    if [[ $? == 0 ]]; then
                        ln -s $plfs_src_dir ${srcdir}/plfs >> $plfs_build_log 2>&1
                        if [[ $? == 0 ]]; then
                            plfs_ok="PASS"
                        else
                            plfs_ok="FAIL"
                        fi
                    else
                        plfs_ok="FAIL"
                    fi
                    if [ "$plfs_ok" == "PASS" ]; then
                        echo "Successfully linked" >> $plfs_build_log
                        plfs_stat="successfully linked"
                    else
                        echo "Unable to link" >> $plfs_build_log
                        plfs_stat="unable to link"
                    fi
                else
                    plfs_stat="unable to create new plfs installation"
                    plfs_ok="FAIL"
                fi
            fi
        fi
    else
        echo "Building plfs..." | tee $plfs_build_log
        # Copy the src from plfs_src_from
        ${basedir}/src_cp.sh $plfs_src_from ${srcdir}/plfs >> $plfs_build_log 2>&1
#        grep -q processor /proc/cpuinfo
        if [[ $? == 0 ]]; then
            # Build the plfs source
            ${basedir}/plfs_build.sh ${srcdir}/plfs $instdir/plfs >> $plfs_build_log 2>&1
#            grep -q processor /proc/cpuinfo

            # Find out if the build was successful
            if [[ $? == 0 ]]; then
                plfs_stat="Successfully built and installed"
                plfs_ok="PASS"
                plfs_bin_dir="${instdir}/plfs/bin"
                plfs_lib_dir="${instdir}/plfs/lib"
                plfs_inc_dir="${instdir}/plfs/include"
            else
                plfs_stat="Building failed"
                plfs_ok="FAIL"
            fi
        else
            plfs_stat="Copying source failed"
            plfs_ok="FAIL"
        fi
    fi
    # final sanity check on the needed plfs directories
    if [ ! -d "${instdir}/plfs/bin" ]; then
        echo "ERROR: ${instdir}/plfs/bin is not avaliable.." 2>&1
        plfs_ok="FAIL"
    fi
    if [ ! -d "${instdir}/plfs/sbin" ]; then
        echo "ERROR: ${instdir}/plfs/sbin is not avaliable.." 2>&1
        plfs_ok="FAIL"
    fi
    if [ ! -d "${instdir}/plfs/lib" ]; then
        echo "ERROR: ${instdir}/plfs/lib is not avaliable.." 2>&1
        plfs_ok="FAIL"
    fi
    if [ ! -d "${instdir}/plfs/include" ]; then
        echo "ERROR: ${instdir}/plfs/include is not avaliable.." 2>&1
        plfs_ok="FAIL"
    fi

    # Get the necessary flags for building against PLFS. This will set
    # RS_PLFS_LDFLAGS and RS_PLFS_CFLAGS
    setup_rs_plfs_flags
    if [[ $? != 0 ]]; then
        echo "Error setting PLFS build flags" >> $plfs_build_log
        plfs_stat="problem setting PLFS build flags"
        plfs_ok="FAIL"
    fi

    echo $plfs_stat
    if [ "$plfs_ok" == "FAIL" ]; then
        script_exit 1
    fi

    #MPI
    echo "Checking mpi. Please see $mpi_build_log."
    if [ "$openmpi_tarball" == "None" ]; then
        # Use an already existing version of mpi. mpi_bin_dir, mpi_lib_dir and
        # mpi_inc_dir will already be defined. Check to make sure all is well.
        echo "Linking mpi..." | tee $mpi_build_log
        # Check for a binary
        if [ -e "$mpi_bin_dir/$MPI_CC" ]; then
            echo "Found $mpi_bin_dir/$MPI_CC" >> $mpi_build_log
        else
            echo "$mpi_bin_dir/$MPI_CC not found. It does not appear that $mpi_bin_dir contains mpi binaries." >> $mpi_build_log
            mpi_stat="mpi binaries not found"
            mpi_ok="FAIL"
        fi
        # Check for libmpi
        ls $mpi_lib_dir | grep -q libmpi
        if [[ $? != 0 ]]; then
            echo "libmpi* was not found in $mpi_lib_dir. It does not appear that $mpi_lib_dir contains mpi libraries." >> $mpi_build_log
            mpi_stat="mpi libraries not found"
            mpi_ok="FAIL"
        fi
        # Check for mpi headers
        if [ -e "$mpi_inc_dir/mpi.h" ]; then
            echo "Found $mpi_inc_dir/mpi.h" >> $mpi_build_log
        else
            echo "$mpi_inc_dir does not contain a mpi.h. It does not appear that $mpi_inc_dir contains mpi headers." >> $mpi_build_log
            mpi_stat="mpi headers not found"
            mpi_ok="FAIL"
        fi
        if [ "$mpi_ok" == "PASS" ]; then
            # If we're here, mpi has been successfully found. Link it in to
            # the regression suite so tests can know where to always find it.
            mpi_stat="mpi successfully found"
            if [ -d "${instdir}/mpi" ]; then
                rm -rf "${instdir}/mpi" >> $mpi_build_log 2>&1
                if [ -d "${instdir}/mpi" ]; then
                    mpi_stat="unable to remove old mpi installation"
                    mpi_ok="FAIL"
                fi
            fi
            if [ ! -d "${instdir}/mpi" ]; then
                mkdir ${instdir}/mpi >> $mpi_build_log 2>&1
                if [[ $? == 0 ]]; then
                    echo "Linking..." >> $mpi_build_log
                    ln -s $mpi_bin_dir ${instdir}/mpi/bin >> $mpi_build_log 2>&1 && \
                        ln -s $mpi_lib_dir ${instdir}/mpi/lib >> $mpi_build_log 2>&1 && \
                        ln -s $mpi_inc_dir ${instdir}/mpi/include >> $mpi_build_log 2>&1
                    if [[ $? == 0 ]]; then
                        echo "Successfully linked" >> $mpi_build_log
                        mpi_stat="successfully linked"
                        mpi_ok="PASS"
                    else
                        echo "Unable to link" >> $mpi_build_log
                        mpi_stat="unable to link"
                        mpi_ok="FAIL"
                    fi
                else
                    mpi_stat="unable to create directory"
                    mpi_ok="FAIL"
                fi
            fi
        fi
    else
        # Build openmpi. 
        echo "Building and installing openmpi." | tee $mpi_build_log
        # Compile openmpi from a tarball
        ${basedir}/openmpi_build.sh $openmpi_tarball $srcdir $instdir/mpi \
        ${srcdir}/plfs ${ompi_platform_file} \
        >> $mpi_build_log 2>&1
        if [[ $? == 0 ]]; then
            mpi_stat="Successfully built and installed"
            mpi_ok="PASS"
            mpi_bin_dir="${instdir}/mpi/bin"
            mpi_lib_dir="${instdir}/mpi/lib"
            mpi_inc_dir="${instdir}/mpi/include"
        else
            mpi_stat='Failed to build and install'
            mpi_ok="FAIL"
        fi
    fi
    echo $mpi_stat
    # final sanity check on the needed mpi directories
    if [ ! -d "${instdir}/mpi/bin" ]; then
        echo "ERROR: ${instdir}/mpi/bin is not avaliable." 2>&1
        mpi_ok="FAIL"
    fi
    if [ ! -d "${instdir}/mpi/lib" ]; then
        echo "ERROR: ${instdir}/mpi/lib is not avaliable." 2>&1
        mpi_ok="FAIL"
    fi
    if [ ! -d "${instdir}/mpi/include" ]; then
        echo "ERROR: ${instdir}/mpi/include is not avaliable." 2>&1
        mpi_ok="FAIL"
    fi

    if [ "$mpi_ok" == "FAIL" ]; then
        script_exit 1
    fi

    # set up the environment to use the regression suite's binaries and
    # libraries
    source ${basedir}/tests/utils/rs_env_init.sh >> /dev/null

    # experiment_management
    echo "Checking experiment_management. Please see $expr_mgmt_get_log."
    expr_dir="${instdir}/experiment_management"
    # Remove the old inst/experiment_management directory if needed
    if [ -d "$expr_dir" ]; then
        echo "Removing $expr_dir" > $expr_mgmt_get_log 2>&1
        rm -rf $expr_dir >> $expr_mgmt_get_log 2>&1
        if [ -d "$expr_dir" ]; then
            echo "Error: Unable to remove $expr_dir" >> $expr_mgmt_get_log 2>&1
            expr_mgmt_stat="unable to remove old experiment_management installation"
            expr_mgmt_ok="FAIL"
        fi
    fi

    if [ "$expr_mgmt_ok" == "PASS" ]; then
        if [ "$expr_mgmt_src_from" == "None" ]; then
            # Use a location elsewhere on the system. Don't copy it.
            echo "Linking experiment_management..." | tee -a $expr_mgmt_get_log
            ln -s $expr_mgmt_loc $expr_dir >> $expr_mgmt_get_log 2>&1
            if [ ! -d "${expr_dir}" ]; then
                expr_mgmt_stat="unable to link"
                expr_mgmt_ok="FAIL"
            else
                expr_mgmt_stat="successfully linked"
                expr_mgmt_ok="PASS"
            fi
        else
            # Copy the directory into the regression suite's installation directory
            echo "Copying experiment_management..." | tee -a $expr_mgmt_get_log
            ${basedir}/src_cp.sh $expr_mgmt_src_from $expr_dir >> $expr_mgmt_get_log 2>&1
            if [[ $? == 0 ]]; then
                expr_mgmt_stat="successfully copied"
                expr_mgmt_ok="PASS"
            else
                expr_mgmt_stat="unable to copy"
                expr_mgmt_ok="FAIL"
            fi
        fi

        # Now check that we have a valid experiment_management framework if
        # everything has gone well up to this point.
        if [ "$expr_mgmt_ok" == "PASS" ]; then
            if [ ! -e "$expr_dir/run_expr.py" ] || \
                [ ! -f "$expr_dir/lib/expr_mgmt.py" ] || \
                [ ! -f "$expr_dir/lib/fs_test.py" ]; then
                expr_mgmt_stat="$expr_dir is not a valid experiment_management framework."
                expr_mgmt_ok="FAIL"
                echo $expr_mgmt_stat >> $expr_mgmt_get_log
                echo "The following files are expected for a valid framework:" >> $expr_mgmt_get_log
                echo "experiment_management/run_expr.py (must be executable)" >> $expr_mgmt_get_log
                echo "experiment_management/lib/expr_mgmt.py" >> $expr_mgmt_get_log
                echo "experiment_management/lib/fs_test.py" >> $expr_mgmt_get_log
            fi
        fi
    fi
    echo $expr_mgmt_stat
    if [ "$expr_mgmt_ok" == "FAIL" ]; then
        script_exit 1
    fi

    # fs_test
    echo "Checking fs_test. Please see $fs_test_build_log."
    # Since we may have multiple versions of the fs_test executable, the fs_test_build.sh
    # script will not remove previous versions of the executable from the installation
    # location. We will do it once here.
    if [ -d "${instdir}/test_fs" ]; then
        echo "Removing $instdir/test_fs" > $fs_test_build_log 2>&1
        rm -rf $instdir/test_fs >> $fs_test_build_log 2>&1
        if [ -d "${instdir}/test_fs" ]; then
            echo "Error: Unable to remove $instdir/test_fs" >> $fs_test_build_log 2>&1
            fs_test_stat="unable to remove old fs_test installation"
            fs_test_ok="FAIL"
        fi
    fi
    
    if [ "$fs_test_ok" == "PASS" ]; then
        if [ "$fs_test_src_from" == "None" ]; then
            # Getting the executable from somewhere else (not compiling it here).
            echo "Linking fs_test..." | tee -a $fs_test_build_log
            # We already know, based on the check on the config file, that the
            # fs_test executable is a valid executable. Just link it in to the
            # regression suite
            fs_test_stat="fs_test successfully found"
            # The directory should already be removed or we wouldn't be in this
            # code block.
            mkdir ${instdir}/test_fs >> $fs_test_build_log 2>&1
            ln -s $fs_test_loc ${instdir}/test_fs/fs_test.${MY_MPI_HOST}.x >> $fs_test_build_log 2>&1
            if [ ! -e "${instdir}/test_fs/fs_test.${MY_MPI_HOST}.x" ]; then
                fs_test_stat="unable to create new fs_test installation"
                fs_test_ok="FAIL"
            else
                fs_test_stat="successfully linked"
                fs_test_ok="PASS"
            fi
        else
            echo "Building fs_test..." | tee -a $fs_test_build_log
            # Copy the source
            ${basedir}/src_cp.sh $fs_test_src_from $srcdir/test_fs > $fs_test_build_log 2>&1
            #grep -q processor /proc/cpuinfo
            if [[ $? == 0 ]]; then
                # Build fs_test
                ${basedir}/fs_test_build.sh $srcdir ${instdir}/test_fs >> $fs_test_build_log 2>&1
                #grep -q processor /proc/cpuinfo
                if [[ $? == 0 ]]; then
                    fs_test_stat="Successfully built and installed"
                    fs_test_ok="PASS"
                else
                    fs_test_stat="Building and installing failed"
                    fs_test_ok="FAIL"
                fi
            else
                fs_test_stat="Copying source failed"
                fs_test_ok="FAIL"
            fi
        fi
    fi

    echo $fs_test_stat | tee -a $fs_test_build_log
    if [ "$fs_test_ok" == "FAIL" ]; then
        script_exit 1
    fi
else
    echo "--nobuild used...skipping source retrevial and building"
    plfs_stat="skipped due to configuration"
    plfs_ok="PASS"
    mpi_stat="skipped due to configuration"
    mpi_ok="PASS"
    fs_test_stat="skipped due to configuration"
    fs_test_ok="PASS"
    expr_mgmt_stat="skipped due to configuration"
    expr_mgmt_ok="PASS"

    # call the function that will set up the necessary flags for building
    # against plfs. This will set RS_PLFS_LDFLAGS and RS_PLFS_CFLAGS
    setup_rs_plfs_flags
    if [[ $? != 0 ]]; then
        plfs_stat="Error setting PLFS build flags"
        plfs_ok="FAIL"
        script_exit 1
    fi

    # Call the helper script that will set up the environment to use the
    # regression suite's binaries and libraries.
    source ${basedir}/tests/utils/rs_env_init.sh >> /dev/null
fi

# Now, do some rc file checking
echo "Checking for plfs and experiment_management rc file existance. Please see $config_file_log."
# Check for FATAL problems when dealing with the plfsrc files. These
# can't be ignored and need to be fixed.
echo "Checking for plfs rc file..." > $config_file_log
output=`plfs_check_config 2>&1`
echo $output | grep "FATAL" >> /dev/null
if [[ $? == 0 ]]; then
    config_file_stat="FATAL problem with using plfs_check_config on a plfsrc file; please fix the rc file(s)"
    config_file_ok="FAIL"
    echo $config_file_stat >> $config_file_log
    echo "plfs_check_config output:" >> $config_file_log
    plfs_check_config >> $config_file_log 2>&1
else
    echo "plfsrc file found and no FATAL errors when plfs_check_config was called." >> $config_file_log
fi
if [ "$config_file_ok" != "PASS" ]; then
    echo $config_file_ok | tee -a $config_file_log
    script_exit 1
fi

# Check for exprmgmtrc
echo "Checking for experiment_management rc file..." >> $config_file_log
if [ -e ~/.exprmgmtrc ] || [ -e "$EXPRMGMTRC" ]; then
    echo "Found experiment_management rc file." >> $config_file_log
    echo "Checking experiment_management rc file for runcommand, outdir, and ppn..." >> $config_file_log
    missing=""
    # Check for runcommand
    runcommand=`tests/utils/rs_exprmgmtrc_option_value.py \
        runcommand`
    if [ "$runcommand" == "" ]; then
        missing="$missing, runcommand"
    fi
    # Check for ppn
    ppn=`tests/utils/rs_exprmgmtrc_option_value.py ppn`
    if [ "$ppn" == "" ]; then
        missing="$missing, ppn"
    fi
    # Check for outdir
    outdir=`tests/utils/rs_exprmgmtrc_option_value.py outdir`
    if [ "$outdir" == "" ]; then
        missing="$missing, outdir"
    fi
    if [ "$missing" != "" ]; then
        # Remove ', ' from the beginning of the string
        missing=${missing:2}
        config_file_stat="experiment_management rc file doesn't define the following: $missing"
        config_file_ok="FAIL"
        echo $config_file_stat >> $config_file_log
    else
        echo "Required parameters found in experiment_management rc file." >> $config_file_log
    fi
else
    config_file_stat="Valid rc file for experiment_management not found."
    config_file_ok="FAIL"
    echo $config_file_stat >> $config_file_log
    echo "Please create ~/.exprmgmtrc or set the environment variable" >> $config_file_log
    echo "EXPRMGMTRC to a valid experiment_management rc file." >> $config_file_log
fi
echo $config_file_ok | tee -a $config_file_log
if [ "$config_file_ok" != "PASS" ]; then
    script_exit 1
else
    config_file_stat="Checked"
fi

# Make sure all plfs directories are available.
# Get the mount points from the plfs config, ignoring errors since the
# directories may not exist yet.
query_script=${basedir}/tests/utils/rs_plfs_config_query.py
mount_points=`${query_script} -m -i`
if [ $? != 0 ]; then
    echo "ERROR: Unable to get PLFS mount point(s) using ${query_script}"
    script_exit 1
fi

for mount_point in $mount_points; do
    # Check that the mount point directory is created
    if [ ! -d $mount_point ]; then
        echo "Attempting to create directory $mount_point..."
        mkdir -p $mount_point
        if [ $? != 0 ]; then
            echo "ERROR: Problem creating directory $mount_point"
            script_exit 1
        else
            echo "Successfully created"
        fi
    fi
    # Now get the backends for this mount point, ignoring errors
    backends=`$query_script -b -i $mount_point`
    if [ $? != 0 ]; then
        echo "ERROR: Unable to get PLFS backends for $mount_point using ${query_script}"
        script_exit 1
    fi
    for backend in $backends; do
        # Check that the backend directory is there; create if not there
        if [ ! -d $backend ]; then
            echo "Attempting to create directory $backend..."
            mkdir -p $backend
            if [ $? != 0 ]; then
                echo "ERROR: Problem creating directory $backend"
                script_exit 1
            else
                echo "Successfully created"
            fi
        fi
        # Check that the needed subdirectory is there in the backend
        # First, get the name of the subdirectory, if it exists
        append_path=`tests/utils/rs_exprmgmtrc_option_value.py \
            rs_mnt_append_path`
        if [ "$append_path" != "" ]; then
            # Check if it is there and create it if it isn't.
            if [ ! -d $backend/$append_path ]; then
                echo "Attempting to create directory $backend/$append_path..."
                mkdir -p $backend/$append_path
                if [ $? != 0 ]; then
                    echo "ERROR: Problem creating directory $backend/$append_path"
                    script_exit 1
                else
                    echo "Successfully created"
                fi
            fi
        fi
    done
done

if [ "$runtests" == "True" ]; then
    echo "Submitting tests. See $submit_tests_log."
    # Submit tests
    ${basedir}/submit_tests.py --control=$control_file --idfile=$id_file \
        --dictfile=$dict_file --basedir=${basedir} --types=$testtypes \
        > $submit_tests_log 2>&1
    ret=$?
    if [[ $ret == 0 ]]; then
        submit_test_stat="PASS"
    elif [[ $ret == 2 ]]; then
        submit_test_stat="WARNING: errors in parsing $control_file"
    else
        submit_test_stat="FAIL: no tests submitted"
    fi
    echo $submit_test_stat
    if [ "${submit_test_stat:0:4}" == 'FAIL' ]; then
        script_exit 1
    fi
else
    echo "--notests used...skipping running of tests."
fi
# Exit
script_exit 0
