#!/bin/bash
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

# Get the tests/utils directory
utils_dir="$basedir/tests/utils"

# Source a personal customization script, if it exists
customize="${utils_dir}/env_customize.sh"
if [ -f "$customize" ]; then
    echo "Sourcing $customize"
    source $customize
fi
