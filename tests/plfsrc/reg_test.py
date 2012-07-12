#!/usr/bin/env python
#
# Test rename in plfs. Uses fuse interface.

import os,sys,getpass,re,datetime,subprocess
from time import localtime, strftime, sleep

user = getpass.getuser()

# Figure out the base directory of the regression suite
curr_dir = os.getcwd()
basedir = re.sub('tests/plfsrc.*', '', curr_dir)

# Add the directory that contains the helper scripts
utils_dir = basedir + "tests/utils"
if utils_dir not in sys.path:
    sys.path += [ utils_dir ]

# Add the module that will help get plfs mount points
import rs_plfs_config_query as pcq

# Set up the right environment
import rs_env_init

# Import the module for dealing with experiment_management paths
import rs_exprmgmt_paths_add as emp
# Add the experiment_management location to sys.path
emp.add_exprmgmt_paths(basedir)
import expr_mgmt

import rs_exprmgmtrc_target_path_append as tpa

class plfsrcError(Exception):
    def __init__(self, msg):
        self.msg = msg
    def __str__(self):
        return str(self.msg)

def main(argv=None):
    """Main method for running this test.

    Return values:
     0: Test ran
    -1: Problem with opening the log file.
    """
    # Where the output of the test will be placed.
    out_dir = (str(expr_mgmt.config_option_value("outdir")) + "/"
        + str(datetime.date.today()))
    # Create the directory if needed
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    out_file = (str(out_dir) + "/" + str(strftime("%H-%M-%S", localtime())) + ".log")
    try:
        of = open(out_file, 'w')
    except OSError, detail:
        print ("Error: unable to create log file " + str(out_file) + ": " + str(detail))
        return [ -1 ]
        
    old_stdout = sys.stdout
    old_stderr = sys.stderr
    sys.stdout = of
    sys.stderr = of
    
    # Set up paths to plfs install directories
    rs_env_init.add_plfs_paths(basedir)

    # Test status. This will be printed out at the end and will be used to
    # determine if the test passed when check_results.py is called.
    test_stat = "FAILED"

    try:
            # Call the truncate_open_file.bash script with the two files
            p = subprocess.Popen(['./test_plfsrc.bash'], stdout=of, stderr=of, shell=True)
            p.communicate()
            if p.returncode == 0:
                test_stat = "PASSED"
        
    except plfsrcError, detail:
        print("Problem dealing with plfsrc file: " + str(detail))
    else:
        print("The test " + str(test_stat))
    finally:
        # Close up shop
        sys.stdout.flush()
        sys.stderr.flush()
        of.close()
        sys.stdout = old_stdout
        sys.stderr = old_stderr
        # If we're here, we're done. We don't know if the test passed, but that
        # doesn't matter; it will be check_tests.py job to determine that. Let
        # the calling process know that it needs to check results of this test.
        return [ 0 ]

if __name__ == "__main__":
    ret = main()
    # ret is a list, so we don't want to just return it. At this point, we just
    # return a 0.
    sys.exit(0)
