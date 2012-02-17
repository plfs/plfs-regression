#!/usr/bin/env python
#
# This is a wrapper script for finding options in experiment_managment's rc
# file. It's usage is as follows:
#
# rs_exprmgmt_rc_option_value.py <option>
#
# where <option> is the option to search for.
#
# Exit status:
# 0: the option was found. The option's value will have been printed out.
# 1: the option was not found. Error messages from expr_mgmt.py will have
#    been printed out.
#

import os, sys, re

# This script is probably not invoked from the directory it resides in. Figure
# out where this script is located because the experiment_managment helper
# scripts should be in the same directory.

# Get the current working directory
save_dir = os.getcwd()
# Get the directory of the script. This could be a relative path.
script_dir = os.path.dirname(__file__)
# Change directory to that directory
os.chdir(script_dir)
# Get the current working directory again. This is what is needed.
ab_script_dir = os.getcwd()
# Go back to the original directory
os.chdir(save_dir)

# Add ab_script_dir to the path if needed
if ab_script_dir not in sys.path:
    sys.path += [ ab_script_dir]

# Figure out the regression suite's base directory from ab_script_dir
basedir = re.sub('tests/utils.*', '', ab_script_dir)

# Import the module for dealing with experiment_managment paths
import rs_exprmgmt_paths_add as emp
# Add the experiment_management location to sys.path
emp.add_exprmgmt_paths(basedir)
import expr_mgmt

def main(argv=None):
    if len(argv) != 2:
        print "Usage:"
        print "rs_exprmgmtrc_option_value.py OPTION\n"
        print ("where OPTION is the value to search for in "
            + "experiment_management's rc file.\n")
        return 1

    value = expr_mgmt.config_option_value(str(argv[1]))
    if value == None:
        return 1
    else:
        print value
        return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
