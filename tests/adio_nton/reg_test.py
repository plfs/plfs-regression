#!/usr/bin/env python
#
# Run a plfs regression test.

import os,sys,re,imp,subprocess

# Load the common.py module to get common variables
(fp, path, desc) = imp.find_module('test_common', [os.getcwd()])
tc = imp.load_module('test_common', fp, path, desc)
fp.close()

import run_expr

def main(argv=None):
    """The main routine for submitting and running a test.

    Returns a list of job ids submitted for this test.
    """
    if argv == None:
        argv = sys.argv

    # Experiment_management script to run
    input = tc.curr_dir + "/input.py"
    # Generated script
    script = "reg_test.sh"
    # Script that can be passed to experiment_management that will run the
    # generated script
    input_script = "input_script.py"
    walltime = "40:00"

    # get all mountpoints and associated target path and file
    target_paths = tc.get_target_paths()
    if target_paths == None:
        print ("Error getting mountpoint")
        return [-1]

    # Create the script
    try:
        f = open(script, 'w')
        f.write('#!/bin/bash\n')
        # Set up the environment
        f.write('source ' + str(tc.basedir) + '/tests/utils/rs_env_init.sh\n')
        # Check environment variables to make sure we're using the right
        # binaries and libraries.
        f.write("echo PATH=$PATH\n")
        f.write("echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH\n")

        # Convert target path list into space delimited targets 
        paths=' '.join(target_paths)
        # Create a for loop to iterate throuh all mountpoints/paths
        f.write('for path in ' + str(paths) + '\n')
        f.write('do\n')
        f.write('   echo Using $path as target\n')
        fs_test_command = str(tc.em_p.get_expr_mgmt_dir(tc.basedir)) + "/run_expr.py --dispatch=list " + str(input)

        cmd = subprocess.Popen([fs_test_command], stdout=subprocess.PIPE, shell=True)
        fs_test_run, errors = cmd.communicate()
        f.write("   " + str(fs_test_run) + '\n')
        f.write('done\n')
        f.close()
    except (IOError, OSError), detail:
        print ("Problem with creating script " + str(script) 
            + ": " + str(detail))
        return [-1]

    # Run the script
    last_id = run_expr.main(['run_expr', str(tc.curr_dir) + "/" + str(input_script),
        '--nprocs=' + str(tc.nprocs), '--walltime=' + str(walltime), 
        '--dispatch=msub'])
    return [last_id]

if __name__ == "__main__":
    result = main()
    if result[-1] > 0:
        sys.exit(0)
    else:
        sys.exit(1)
