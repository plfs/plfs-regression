#!/usr/bin/env python
#
# Run a plfs regression test.

import sys,imp,os,re,subprocess
sys.path += ['./']

# Load the common.py module to get common variables.
(fp, path, desc) = imp.find_module('test_common', [os.getcwd()])
tc = imp.load_module('test_common', fp, path, desc)
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
    walltime = "10:00"

    # Figure out the mounts for this test
    mounts = tc.get_mountpoints()
    if mounts == None:
        print ("Error getting mounts")
        return [-1]
    # Get the target filename
    filename = tc.get_filename()
    # Define utils directory
    utils_dir = (tc.basedir + "/tests/utils/")

# Prescript and postscript 
    prescript = (tc.basedir + "/tests/utils/rs_plfs_fuse_mount.sh ")
    postscript = (tc.basedir + "/tests/utils/rs_plfs_fuse_umount.sh ")
    
    # Create the script
    try:
        f = open(script, 'w')
        # Write the header including statements to get the correct environment
        f.write('#!/bin/bash\n')
        f.write('source ' + str(tc.basedir) + '/tests/utils/rs_env_init.sh\n')

        # Create a for loop to iterate throuh all mountpoints/paths
        mounts=' '.join(mounts)
        f.write('for mnt in ' + str(mounts) + '\n')
        f.write('do\n')
        f.write("    echo \"Running " + str(prescript) + "$mnt" + "\"\n")
        f.write("    need_to_umount=\"True\"\n")
        # The next section of code is to determine if the script needs to
        # run the unmount command. If rs_plfs_fuse_mount.sh returns with a 1,
        # this test is not going to issue the unmount command.
        f.write("    " + str(prescript) + "$mnt" + "\n")
        f.write("    ret=$?\n")
        f.write("    if [ \"$ret\" == 0 ]; then\n")
        f.write("        echo \"Mounting successful\"\n")
        f.write("        need_to_umount=\"True\"\n")
        f.write("    elif [ \"$ret\" == 1 ]; then\n")
        f.write("        echo \"Mount points already mounted.\"\n")
        f.write("        need_to_umount=\"False\"\n")
        f.write("    else\n")
        f.write("        echo \"Something wrong with mounting.\"\n")
        f.write("        exit 1\n")
        f.write("    fi\n")
        # Generate target for use by fs_test
        f.write('    top=`' + str(utils_dir) + 'rs_exprmgmtrc_target_path_append.py $mnt`\n')
        f.write('    path=$top/' + str(filename) + '\n')
        f.write('    echo Using $path as target\n')
        f.write("    echo \"Attempting to write to non-plfs space\"\n")
        f.write('    for io_type in posix plfs' + '\n')
        f.write('    do\n')
        f.write('        for size in 4194304 2097152 5242880' + '\n')
        f.write('        do\n')

        # Generate the fs_test command
        fs_test_command = str(tc.em_p.get_expr_mgmt_dir(tc.basedir)) + "/run_expr.py --dispatch=list ./input.py" 
        cmd = subprocess.Popen([fs_test_command], stdout=subprocess.PIPE, shell=True)
        fs_test_run, errors = cmd.communicate()
        f.write("            " + str(fs_test_run) + '\n')

        # Deterimine if expected target file size correct
        f.write('            let \"file_size=16*size*1\"\n') 
#        f.write('            target_file_size=`ls -al $path | awk \'{print $5}\'`\n')
        f.write('            target_file_size=`du -bs $path.* | awk \'{sum = sum + $1} END {print sum}\'`\n')

        f.write("            if [ \"$file_size\" != \"$target_file_size\" ]; then\n")
        f.write("                echo \"Error:  target file sizes do not match expected file sizes\"\n")
        f.write("            else\n")
        f.write("                echo \"Target file sizes match expected file sizes\"\n")
        f.write("            fi\n")
        f.write('        done\n')
        # Remove the targets if it is still there
        f.write("        if [ -e $path ]; then\n")
        f.write("            rm -f $path\n")
        f.write("        fi\n")
        f.write('    done\n')
        # Write into the script the script that will unmount plfs
        f.write("    if [ \"$need_to_umount\" == \"True\" ]; then\n")
        f.write("        echo \"Running " + str(postscript) + "$mnt" + "\"\n")
        f.write("        " + str(postscript) + "$mnt" + "\n")
        f.write("    fi\n")
        f.write('done\n')
        f.close()
        # Make the script executable.
        os.chmod(script, 0764)
    except (IOError, OSError), detail:
        print ("Problem with creating script " + str(script) 
            + ": " + str(detail))
        return [-1]


    # Run the script through experiment_management
    last_id = run_expr.main(['run_expr', str(tc.curr_dir) + "/" + str(input_script),
        '--nprocs=' + str(tc.nprocs), '--walltime=' + str(walltime), 
        '--dispatch=msub'])
    return [last_id]
    return [0]

if __name__ == "__main__":
    result = main()
    if result[-1] > 0:
        sys.exit(0)
    else:
        sys.exit(1)
