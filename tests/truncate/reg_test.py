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
# Test truncate in plfs. Uses fuse interface.
# 
# This tests originates from the plfs trunk test subdirectory.  The purpose 
# of this test is to write a known pattern to a file then truncate the file
# and verify the data. 
# 
# Refer to the README for a detailed test description 
# 
# 

import os,sys,getpass,re,datetime,subprocess
from time import localtime, strftime, sleep

user = getpass.getuser()

# Figure out the base directory of the regression suite
curr_dir = os.getcwd()
basedir = re.sub('tests/truncate.*', '', curr_dir)

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

class chkDataError(Exception):
     def __init__(self, msg):
         self.msg = msg
     def __str__(self):
         return str(self.msg) 

def openFile(path,mode):
  f = open(path,mode)
  return f

def checkData(path,data,phase):
  print 'In checkData'
  fdata = None
  f = openFile(path,'r')
  fdata = f.read()
  f.close()
  print 'In checkData after close'
  if (fdata == data): 
    print 'In checkData data ok'
    return 0
  else:
    print 'Data integrity error after %s' % phase
    if(len(fdata)!=len(data)):
      print "Length mismatch %d != %d" %(len(fdata),len(data))
    print 'Expected %s, got %s' % (data[:100],fdata[:100])
#   if (verbose is True):
    for i in range(0,min(len(fdata),len(data))):
        print "%c ? %c" % (data[i],fdata[i])
    return -1

def truncateFile(target,tlen):
  f = openFile(target, 'a')
  f.truncate(tlen)
  print "Truncated %s to %d" % (target,tlen)
  f.flush()
  f.close()

def writeFile(target,data,offset,mode):
  fd = os.open(target, mode)
  f = os.fdopen(fd,'w')
  f.seek(offset,0)
  print "Writing %d bytes to %s at off %d" % (len(data),target,offset)
  f.write(data)
  f.flush()
  os.fsync(fd)
  f.close()



def main(argv=None):
    """Main method for running this test.

    Return values:
     0: Test ran
    -1: Problem with opening log file 
    """
    # Where the output of the test will be placed.
    out_dir = (str(expr_mgmt.config_option_value("outdir")) + "/"
         + str(datetime.date.today()))
    # Create the directory if needed
    if not os.path.isdir(out_dir):
        os.makedirs(out_dir)
    out_file = (str(out_dir) + "/" + str(strftime("%H-%M-%S", 
        localtime())) + ".log")
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
            # Test status
            test_stat = "PASSED"
            p = subprocess.Popen([str(utils_dir) + '/rs_plfs_fuse_mount.sh '
                + str(mount_point) + ' serial'], stdout=of, stderr=of, shell=True)
            p.communicate()
            if p.returncode == 0:
                print (" ")
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
                file_base = os.getenv("MY_MPI_HOST") + ".truncate"
                file_size=1048576
                # Check for rs_mnt_append_path in experiment_management
                top_dir = tpa.append_path([mount_point])[0]
                file1 = str(top_dir) + "/" + str(file_base) + "1"
                data="a"*file_size
        
                # create the file
                writeFile(file1,data,0,os.O_WRONLY|os.O_CREAT|os.O_TRUNC)
                if checkData(file1,data,phase='write') == -1:
                    raise chkDataError("Problem with post write data check\n")

                # truncate it
                tlen = int(file_size/2)
                truncateFile(file1,tlen)
                data=data[:tlen]
                if checkData(file1,data,phase='truncate') == -1:
                    raise chkDataError("Problem with post truncate data check\n")

                # overwrite a tenth of it
                data2="b"*int(file_size/10)
                offset=int(file_size/5)
                expected  = data[:offset]
                expected += data2
                expected += data[offset+len(data2):len(data)]
                writeFile(file1,data2,offset,os.O_WRONLY)
                if checkData(file1,expected,phase='overwrite') == -1:
                    raise chkDataError("Problem with post overwrite data check\n")

                # truncate it one more time in the middle of the overwritten piece
                tlen = offset + int(len(data2)/2)
                expected=expected[:tlen]
                truncateFile(file1,tlen)
                if checkData(file1,expected,phase='truncate2') == -1:
                    raise chkDataError("Problem with second truncate data check\n")

                # Remove the file
                print("Removing " + str(file1))
                os.remove(file1)
            except (OSError, IOError), detail:
                print("Problem in working with file " + str(file1) + ": " + str(detail))
                test_stat = "FAILED"
            except chkDataError, detail:
                print("Data Verification Error: " + str(detail))
                test_stat = "FAILED"

            # Unmount the plfs mount point
            if need_to_umount == True:
                print ("Unmounting " + str(mount_point))
                sys.stdout.flush()
                sys.stderr.flush()
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
        test_stat = "FAILED"
    else:
        print("The test " + str(overall_stat))
    finally:
        # Close up shop
        of.close()
        sys.stdout = old_stdout
        sys.stderr = old_stderr
        return [ 0 ]

if __name__ == "__main__":
    # If reg_test.py is being called directly, make sure the regression suite's
    # PLFS and MPI are in the appropriate environment variables. This should
    # work because test_common was already loaded.
    import rs_env_init
    rs_env_init.add_plfs_paths(basedir)

    ret = main()
    # ret is a list, so don't return it to the shell. Instead, at this point,
    # return a 0.
    sys.exit(0)
