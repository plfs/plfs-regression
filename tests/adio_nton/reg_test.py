#!/usr/bin/env python
#
# Run a plfs regression test.

import os,sys,re

# Figure out the base directory of the regression suite
curr_dir = os.getcwd()
basedir = re.sub('tests/adio_nton.*', '', curr_dir)

# Add the directory that contains the helper scripts
utils_dir = basedir + "tests/utils"
if utils_dir not in sys.path:
    sys.path += [ utils_dir ]

import rs_plfs_config_query

# Add the experiment_management locations to sys.path
import rs_exprmgmt_paths_add as emp
emp.add_exprmgmt_paths(basedir)

import run_expr
import expr_mgmt

def main(argv=None):
    """The main routine for submitting and running a test.

    Returns a list of job ids submitted for this test.
    """
    if argv == None:
        argv = sys.argv

    # Generated script
    script = "reg_test.sh"
    # Script that can be passed to experiment_management that will run the
    # generated script
    input_script = "input_script.py"
    walltime = "15:00"
    # Make sure this matches what is in input.py for n in mpi_options. Want
    # enough to cover at least two nodes.
    ppn = expr_mgmt.config_option_value("ppn")
    nprocs = 2 * int(ppn)

    # Make sure we can get a valid mount_point. The variable mount_points is
    # not used again, but this code is valuable because where we do use it
    # in one of the other scripts, there is no error checking to make sure we
    # got a valid mount point and target. So the following is just for
    # error checking.
    mount_points = rs_plfs_config_query.get_mountpoints()
    if len(mount_points) == 0:
        print ("Error getting a valid mount point.")
        return [-1]

    # Create the script
    try:
        f = open(script, 'w')
        f.write('#!/bin/bash\n')
        # Set up the environment
        f.write('source ' + str(basedir) + '/tests/utils/rs_env_init.sh\n')
        # Check environment variables to make sure we're using the right
        # binaries and libraries.
        f.write("echo PATH=$PATH\n")
        f.write("echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH\n")
        f.close()
        os.system(str(basedir) + "/inst/experiment_management/run_expr.py "
            + "--dispatch=list "
            + "./input.py >> " + str(script))
        os.chmod(script, 0764)
    except (IOError, OSError), detail:
        print ("Problem with creating script " + str(script) 
            + ": " + str(detail))
        return [-1]

    # Run the script
    last_id = run_expr.main(['run_expr', str(curr_dir) + "/" + str(input_script),
        '--nprocs=' + str(nprocs), '--walltime=' + str(walltime), 
        '--dispatch=msub'])
    return [last_id]

if __name__ == "__main__":
    result = main()
    if result[-1] > 0:
        sys.exit(0)
    else:
        sys.exit(1)
