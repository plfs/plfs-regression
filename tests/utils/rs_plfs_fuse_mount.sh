#!/bin/bash
#
# This script is used to mount plfs onto mountpoints using executables from
# the regression suite. It uses scripts in the plfs installation and the
# utilities module in the ioandnetworking repository.
#
# The return values are 0 through 2:
#
# 0: Mount points are ok and the script had to mount them.
# 1: Mount points are ok but the script did not have to mount them.
# 2: Mount points are not ok and they are not mounted.


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
    echo "MOUNT is the mount point that needs to be mounted."
    echo "serial is an optional parameter that will tell this script to mount"
    echo "MOUNT only on the current host."
}
    
# Get the location of the base regression directory
basedir=`echo $script_dir | sed 's|tests/utils.*||'`

if [ "$basedir" == "" ]; then
    echo "$script_name: Error: Unable to determine the base directory to the regression suite."
    echo "This script should be located somewhere below the regression/tests directory."
    exit 1
fi

if [[ $# < 1 ]]; then
    echo "$script_name: Error: Insufficient number of command line parameters"
    Usage
    exit 1
fi

mount_point=$1
serial="False"

if [ -n "$2" ]; then
    if [ "$2" == "serial" ]; then
        serial="True"
    else
        echo "$script_name: Error: Invalid command line parameter $2"
        Usage
        exit 1
    fi
fi

mount_status="ok"
need_to_mount="False"

# command to check on plfs status (is it mounted or not).
test_cmd="grep Uptime ${mount_point}/.plfsdebug >> /dev/null 2>&1"
mnt_cmd="${basedir}/inst/plfs/sbin/plfs $mount_point"

# Are we mounting plfs in serial or parallel?
if [ "$serial" == "True" ]; then #Serial
    if [ -d "$mount_point" ]; then
        # The mount point exists. Is it mounted already?
        eval $test_cmd
        if [ $? == 0 ]; then
            # It is already mounted
            echo "$script_name: Mount point $mount_point already mounted."
            need_to_mount="False"
        else
            # It is not already mounted, so mount it.
            need_to_mount="True"
        fi
    else # The mount point does not exist
        echo "$script_name: The mount point $mount_point does not exist. Trying to create it..."
        mkdir -p $mount_point
        if [ $? != 0 ]; then
            echo "$script_name: Error: Unable to create mount point"
            mount_status="bad"
            need_to_mount="False"
        else
            echo "$script_name: Successfully created $mount_point."
            need_to_mount="True"
        fi
    fi
    
    # Mount the plfs mount point if need be
    if [ "$need_to_mount" == "True" ] && [ "$mount_status" == "ok" ]; then
        echo "$script_name: Attempting to mount $mount_point"
        eval $mnt_cmd
        if [ $? == 0 ]; then
            mount_status="ok"
        else
            mount_status="bad"
        fi
    fi
else #parallel
    # Just run rs_computenodes_plfs_launch. It will first check if the
    # mount point is already mounted. If it is, it will return with an
    # exit status of 2. Otherwise, it will try to unmount the mount
    # point, then make sure the mount point exists as a directory, and
    # then try to mount. It will return a 0 if the mount point is 
    # successfully mounted, 1 otherwise.
    echo "$script_name: Executing ${basedir}/tests/utils/rs_computenodes_plfs_launch.csh"
    ${basedir}/tests/utils/rs_computenodes_plfs_launch.csh --plfs=${basedir}/inst/plfs/sbin/plfs --pexec=${basedir}/inst/pexec/pexec --mntpt=$mount_point --plfslib=${basedir}/inst/plfs/lib
    ret=$?
    if [ $ret == 0 ]; then
        # The mount point is successfully mounted
        mount_status="ok"
        need_to_mount="True"
    elif [ $ret == 1 ]; then
        # The mount point is not mounted; there was some problem
        mount_status="bad"
        need_to_mount="True"
    elif [ $ret == 2 ]; then
        # The mount point was already mounted
        mount_status="ok"
        need_to_mount="False"
    else
        # Unknown exit value
        echo "$script_name: Error: rs_computenodes_plfs_launch.csh returned an unknown exit value of $ret"
        mount_status="bad"
    fi
fi
    
# time to exit
if [ "$mount_status" == "ok" ]; then
    if [ "$need_to_mount" == "True" ]; then
        echo "$script_name: mounting successful"
        exit 0
    else
        exit 1
    fi
else
    echo "$script_name: Error: mounting unsuccessful"
    exit 2
fi
