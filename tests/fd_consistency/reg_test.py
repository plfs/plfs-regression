#!/usr/bin/env python
#
# Run a a plfs_mount leak test. 

import os,sys,re,imp

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
#    input = tc.curr_dir + "/input.py"
    in_script = "fd_test.sh"
    # Generated script
    gen_script = "reg_test.sh"
    # Script that can be passed to experiment_management to run the
    # generated script
    input_script = "input_test.py"
    # Walltime of the job(s)
    walltime = "120:00"

    # Create the script
    try:
        f = open(gen_script, 'w')
        # Write the header
        f.write('#!/bin/bash\n')

        f.write("base_dir=" +"" +str(tc.basedir) + "" + "\n")
        f.write("plfs_tarball_path=" + str(os.getcwd()) + "\n")
        f.close()
        os.system(str("cat ") + in_script + " >> " + str(gen_script))

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
