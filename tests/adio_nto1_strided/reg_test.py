#!/usr/bin/env python
#
# Run a simple write/read test using fuse.

import os,sys,re,imp,subprocess

# Load the common.py module to get common variables
(fp, path, desc) = imp.find_module('test_common', [os.getcwd()])
tc = imp.load_module('test_common', fp, path, desc)
fp.close()

# After loading test_common, can load run_expr
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
    gen_script = "reg_test.sh"
    # Script that can be passed to experiment_management to run the
    # generated script
    input_script = "input_test.py"
    # Walltime of the job(s)
    walltime = "40:00"
    
    # get all mountpoints and associated target path and file
    target_paths = tc.get_target_paths()
    if target_paths == None:
        print ("Error getting mountpoint")
        return [-1]

    # Create the script
    try:
        f = open(gen_script, 'w')
        # Write the header
        f.write('#!/bin/bash\n')
        # Write a command that will get the proper environment
        f.write('source ' + str(tc.basedir) + '/tests/utils/rs_env_init.sh\n')
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
        # Make the script executable
        os.chmod(gen_script, 0764)
    except (IOError, OSError), detail:
        print ("Problem with creating script " + str(gen_script) + ": "
            + str(detail))
        return [-1]

    # Run the script through experiment_management
    last_id = run_expr.main(['run_expr', str(tc.curr_dir) + "/"
        + str(input_script), '--nprocs=' + str(tc.nprocs),
        '--walltime=' + str(walltime), '--dispatch=msub'])
    return [last_id]
    return [0]

if __name__ == "__main__":
    result = main()
    if result[-1] > 0:
        sys.exit(0)
    else:
        sys.exit(1)
