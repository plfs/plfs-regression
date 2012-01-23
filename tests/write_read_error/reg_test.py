#!/usr/bin/env python
#
# Run a plfs regression test.

import sys,imp,os,re,subprocess
sys.path += ['./']

# Load the common.py module to get common variables.
(fp, path, desc) = imp.find_module('common', [os.getcwd()])
common = imp.load_module('common', fp, path, desc)
fp.close()

# After loading common.py, can load run_expr
import run_expr

def main(argv=None):
    """The main routine for submitting and running a test.

    Returns a list of job ids submitted for this test.
    """
    if argv == None:
        argv = sys.argv

    # Generated script
    script = "reg_test.sh"
    # Script that can be passed to experiment_management to run the
    # generated script
    input_script = "input_script.py"
    # Walltime for the job(s)
    walltime = "5:00"

    # Figure out the target that this test will be using.
    target = common.get_target()
    if target == None:
        print ("Error getting a target.")
        return [-1]

    # Get the mount_point. No need to check because if there was a problem,
    # it would have been found in getting the target.
    mnt_pt = common.get_mountpoint()

    # Prescript and postscript
    prescript = (common.basedir + "/tests/utils/rs_plfs_fuse_mount.sh "
        + str(mnt_pt))
    postscript = (common.basedir + "/tests/utils/rs_plfs_fuse_umount.sh "
        + str(mnt_pt))
    
    # Compile replace_char.c so that it can be used in the test
    print ("Compiling replace_char.c")
    try:
        retcode = subprocess.call('gcc -o replace_char replace_char.c', 
            shell=True)
    except OSError, detail:
        print >>sys.stderr, ("Problem compiling replace_char.c: " 
            + str(detail))
        return [-1]
    if retcode != 0:
        print >>sys.stderr, ("Compiling replace_char.c failed. Return "
            "code was " + str(retcode))
        return [-1]
    else:
        print ("Compiling succeeded.")

    # Create the script
    try:
        f = open(script, 'w')
        # Write the header including statements to get the correct environment
        f.write('#!/bin/bash\n')
        f.write('source ' + str(common.basedir) + '/tests/utils/rs_env_init.sh\n')
        f.write("echo \"Running " + str(prescript) + "\"\n")
        f.write("need_to_umount=\"True\"\n")
        # The next section of code is to determine if the script needs to
        # run the unmount command. If rs_plfs_fuse_mount.sh returns with a 1,
        # this test is not going to issue the unmount command.
        f.write(str(prescript) + "\n")
        f.write("ret=$?\n")
        f.write("if [ \"$ret\" == 0 ]; then\n")
        f.write("    echo \"Mounting successful\"\n")
        f.write("    need_to_umount=\"True\"\n")
        f.write("elif [ \"$ret\" == 1 ]; then\n")
        f.write("    echo \"Mount points already mounted.\"\n")
        f.write("    need_to_umount=\"False\"\n")
        f.write("else\n")
        f.write("    echo \"Something wrong with mounting.\"\n")
        f.write("    exit 1\n")
        f.write("fi\n")
        f.close()
        # Generate the write command
        os.system(str(common.em_p.get_expr_mgmt_dir(common.basedir))
            + "/run_expr.py ./input_write.py >> " + str(script))
        # Now need to write the command that will change the target so that 
        # reading causes a single error.
        f = open(script, 'a')
        f.write(str(common.curr_dir) + '/replace_char ' + str(target) + ' 0\n')
        f.close()
        # Generate the read command
        os.system(str(common.em_p.get_expr_mgmt_dir(common.basedir))
            + "/run_expr.py ./input_read.py >> " + str(script))
        # Remove the target if it is still there
        os.system("echo \"if [ -e " + str(target) + " ]; then rm " 
            + str(target) + "; fi\" >> " + str(script))
        # Write into the script the script that will unmount plfs
        f = open(script, 'a')
        f.write("echo \"Running " + str(postscript) + "\"\n")
        f.write("if [ \"$need_to_umount\" == \"True\" ]; then\n")
        f.write("    echo \"Running " + str(postscript) + "\"\n")
        f.write("    " + str(postscript) + "\n")
        f.write("fi\n")
        f.close()
        # Make the script executable.
        os.chmod(script, 0764)
    except (IOError, OSError), detail:
        print ("Problem with creating script " + str(script) 
            + ": " + str(detail))
        return [-1]


    # Run the script through experiment_management
    last_id = run_expr.main(['run_expr', str(common.curr_dir) + "/" + str(input_script),
        '--nprocs=' + str(common.nprocs), '--walltime=' + str(walltime), 
        '--dispatch=msub'])
    return [last_id]
#    return [0]

if __name__ == "__main__":
    result = main()
    if result[-1] > 0:
        sys.exit(0)
    else:
        sys.exit(1)
