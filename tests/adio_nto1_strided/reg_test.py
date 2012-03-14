#!/usr/bin/env python
#
# Run a simple write/read test using fuse.

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
    input = tc.curr_dir + "/input.py"
    # Generated script
    gen_script = "reg_test.sh"
    # Script that can be passed to experiment_management to run the
    # generated script
    input_script = "input_test.py"
    # Walltime of the job(s)
    walltime = "10:00"

    # Figure out the target for this test
    target = tc.get_target()
    if target == None:
        print ("Error getting target")
        return [-1]
    
    # Get the mount_point. No need to check because if there was a problem,
    # it would have been found in getting the target.
    mnt_pt = tc.get_mountpoint()
    
    # prescript and postscript
    prescript = (tc.basedir + "/tests/utils/rs_plfs_fuse_mount.sh "
        + str(mnt_pt))
    postscript = (tc.basedir + "/tests/utils/rs_plfs_fuse_umount.sh "
        + str(mnt_pt))

    # Create the script
    try:
        f = open(gen_script, 'w')
        # Write the header
        f.write('#!/bin/bash\n')
        # Write a command that will get the proper environment
        f.write('source ' + str(tc.basedir) + '/tests/utils/rs_env_init.sh\n')
        f.close()
        # Generate the fs_test command through experiment_management
        os.system(str(tc.em_p.get_expr_mgmt_dir(tc.basedir))
            + "/run_expr.py --dispatch=list " + str(input) + " >> " + str(gen_script))
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
