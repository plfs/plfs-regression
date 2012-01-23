#!/bin/bash -l

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
