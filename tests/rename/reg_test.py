#!/usr/bin/env python
#
###################################################################################
# Copyright (c) 2009, Los Alamos National Security, LLC All rights reserved.
# Copyright 2009. Los Alamos National Security, LLC. This software was produced
# under U.S. Government contract DE-AC52-06NA25396 for Los Alamos National
# Laboratory (LANL), which is operated by Los Alamos National Security, LLC for
# the U.S. Department of Energy. The U.S. Government has rights to use,
# reproduce, and distribute this software.  NEITHER THE GOVERNMENT NOR LOS
# ALAMOS NATIONAL SECURITY, LLC MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR
# ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.  If software is
# modified to produce derivative works, such modified software should be
# clearly marked, so as not to confuse it with the version available from
# LANL.
# 
# Additionally, redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following conditions are
# met:
# 
#    Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
#    Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 
#    Neither the name of Los Alamos National Security, LLC, Los Alamos National
# Laboratory, LANL, the U.S. Government, nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY LOS ALAMOS NATIONAL SECURITY, LLC AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL LOS ALAMOS NATIONAL SECURITY, LLC OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
###################################################################################
#
#
# Test rename in plfs. Uses fuse interface.

import os,sys,getpass,re,datetime,subprocess
from time import localtime, strftime, sleep

user = getpass.getuser()

# Figure out the base directory of the regression suite
curr_dir = os.getcwd()
basedir = re.sub('tests/rename.*', '', curr_dir)

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

class plfsMntError(Exception):
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

    try:
        # Get all mount points
        mount_points = pcq.get_mountpoints()
        if len(mount_points) <= 0:
            raise plfsMntError("unable to get mount point.\n")

        # overall_stat informs  the user that at least one test has failed over
        # multiple mounts.
        overall_stat = "PASSED"

        # Loop through all mount points
        for mount_point in mount_points: 
            # test status is used to keep track of test success/failure on a
            # particular mount point.  It is used to inform the user if
            # at least one test failed over multiple mounts
            test_stat = "PASSED"
            # Check for rs_mnt_append_path in experiment_management
            top_dir = tpa.append_path([mount_point])[0]
            # Define two targets
            file_base = os.getenv("MY_MPI_HOST") + ".rename"
            file1 = str(top_dir) + "/" + str(file_base) + "1"
            file2 = str(top_dir) + "/" + str(file_base) + "2"

            # Define a control line
            cont_line = "Looking for something to read\n"

            # variable to keep track of if we need to issue the unmount command.
            need_to_umount = True
       
            # Mount the plfs mount point
            print (" ")
            print("Mounting " + str(mount_point))
            # Flush the output so that the output in the file is somewhat
            # consistent in time.
            sys.stdout.flush()
            sys.stderr.flush() 
            p = subprocess.Popen([str(utils_dir) + '/rs_plfs_fuse_mount.sh '
                + str(mount_point) + ' serial'], stdout=of, stderr=of, shell=True)
            p.communicate()
            if p.returncode == 0:
                print (str(mount_point) + " successfully mounted")
                need_to_umount = True
            elif p.returncode == 1:
                # This script will not issue the unmount command if
                # rs_plfs_fuse_mount.sh returns with a 1.
                print (str(mount_point) + " already mounted")
                need_to_umount = False
            else:
                raise plfsMntError("problem with mounting\nExiting.\n")
        
            try:
                # Write out the control line to file1
                print("Writing file " + str(file1) + " with line " + str(cont_line))
                f = open(file1, 'w')
                f.write(cont_line)
                f.close()
                print("Contents of " + str(file1))
                f = open(file1, 'r')
                for line in f:
                   print(line)
                f.close()
                print("----End of output-----")

                # Rename the file
                print("Renaming " + str(file1) + " to " + str(file2))
                os.rename(file1, file2)

                # Open file2
                print("Opening " + str(file2))
                f = open(file2, 'r')
                print("Reading a line from " + str(file2))
                line = f.readline()
                print("Read the following: " + str(line))
                if line == cont_line:
                    print("Saw expected line in " + str(file2))
                else:
                    print("Incorrect line in " + str(file2))
                # Check one more line
                print("Checking for additional lines in " + str(file2))
                line = f.readline()
                if line != "":
                    print("Error: extra lines in " + str(file2))
                    test_stat = "FAILED"
                else:
                    print("No additional lines found in " + str(file2))
                f.close()

                # Remove the file
                print("Removing " + str(file2))
                os.remove(file2)
            except (OSError, IOError), detail:
                print("Problem in working with file: " + str(detail))
                test_stat = "FAILED"
                
        
            # Unmount the plfs mount point
            if need_to_umount == True:
                sys.stdout.flush()
                sys.stderr.flush()
                print ("Unmounting " + str(mount_point))
                p = subprocess.Popen([str(utils_dir) + '/rs_plfs_fuse_umount.sh '
                    + str(mount_point) + ' serial'], stdout=of, stderr=of, shell=True)
                p.communicate()
                if p.returncode != 0:
                    # Couldn't unmount; treat this as an error.
                    raise plfsMntError("Unable to unmount " + str(mount_point) + "\n")
                else:
                    print ("Successfully unmounted " + str(mount_point))
            if test_stat == "FAILED":
                overall_stat = "FAILED"
     

    except plfsMntError, detail:
        print("Problem dealing with plfs mounts: " + str(detail))
    else:
#        print("The test " + str(test_stat))
        print("The test " + str(overall_stat))
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
