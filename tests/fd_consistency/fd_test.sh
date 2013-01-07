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
# This script is read in by reg_test.py and written to reg_test.sh.  
# The main purpose of this code is to build plfs repeatively and
# look for file descriptor leaks. 

# Initialize variables
fd_prev_cnt=4
#cnt=0
#
# Number of times to build plfs (loop count)
#
cnt_max=10
#
user=${USER}

# Function to end an iteration for a mount point. This function will perform
# tasks that need to be done to make sure everything is cleared away for the
# next iteration. This function can be called when an error is encountered or
# when all tests have performed successfully for an iteration.
#
# Usage:
# iteration_end TARGET COUNT COUNTMAX MOUNT
#
# Input:
# - TARGET: the target directory that the plfs tarball is in. The function 
#   will cd into this directory so that the tarball and directory can be
#   removed.
# - COUNT: which iteration is ending
# - COUNTMAX: how many iterations are going to be run for a given mount point
# - MOUNT: the mount point being worked on
function iteration_end {
    ie_target=$1
    ie_cnt=$2
    ie_cnt_max=$3
    ie_mnt=$4
    cd $ie_target
    rm -f $ie_target/plfs.tar.gz
    rm -rf $ie_target/plfs-2*
    echo ""
    echo "Completed interation $ie_cnt of $ie_cnt_max on $ie_mnt"
}


#plfs_tarball_path=`pwd`
latest_tarball=`/bin/ls -ltr $plfs_tarball_path/*.gz | /usr/bin/tail -1 | /bin/awk '{print $9}'`

if [ "$latest_tarball" == "" ]; then
    echo "Error:  No Tarball Found"
    exit 1
fi
plfs_tarball=`/bin/basename "$latest_tarball"` 
#
# Check to make sure the script that will append experiment_managment's
# rs_mnt_append_path is available.
#
if [ ! -x "$base_dir/tests/utils/rs_exprmgmtrc_target_path_append.py" ]; then
    echo "Failure: $base_dir/tests/utils/rs_exprmgmtrc_target_path_append.py" 
    echo "is not executable and must be"
    exit 1
fi
source $base_dir/tests/utils/rs_env_init.sh

for io_pattern in "n-n" "n-1"
do
    mount_points=`$base_dir/tests/utils/rs_plfs_config_query.py -m -i -t $io_pattern`
    if [ $? == 0 ]; then
        echo "io_pattern $io_pattern"
        need_to_umount="True"

        for mnt in $mount_points 
        do
            echo "Running $base_dir/tests/utils/rs_plfs_fuse_mount.sh  $mnt serial"
           $base_dir/tests/utils/rs_plfs_fuse_mount.sh $mnt serial
           ret=$?
           if [  "$ret" == 0 ]; then
              echo "Mounting successful"
              need_to_umount="True"
           elif [ "$ret" == 1 ]; then
              echo "Mount points already mounted."
              need_to_umount="False"
           else
              echo "Something wrong with mounting."
              continue
           fi

           target=`$base_dir/tests/utils/rs_exprmgmtrc_target_path_append.py $mnt`

           # loop cnt times building of plfs
           cnt=0
           while [ $cnt -lt $cnt_max ]
           do
               let "cnt += 1"
               echo ""
               echo "Test iteration $cnt on mount $mnt" 
               #setup to build plfs from tarball      
               echo "Copying $plfs_tarball_path/$plfs_tarball to $target"
               cp $plfs_tarball_path/$plfs_tarball $target/.

               cd $target

               # untar and build plfs
               echo "Untarring plfs"
               tar -xzf $plfs_tarball
               ret=$?
               if [[ $ret != 0 ]]; then
                   echo "ERROR: unable to untar $plfs_tarball"
                   iteration_end $target $cnt $cnt_max $mnt
                   continue
               fi
               echo "Done untarring" 

               # figure out plfs directory name
               plfs_dir=`/bin/ls -al | grep drw | grep plfs | awk '{print $9}'`
               echo $plfs_dir
               echo "Changing directory to $plfs_dir" 
               cd $plfs_dir
     
               # make plfs
               echo "make distclean"
               make distclean
               echo "Running configure"
               ./configure
               ret=$?
               if [[ $ret != 0 ]]; then
                   echo "ERROR: configure failed with exit value $ret"
                   iteration_end $target $cnt $cnt_max $mnt
                   continue
               fi

               echo "Running make -j"
               make -j
               ret=$?
               if [[ $ret != 0 ]]; then
                   echo "ERROR: make failed with exit value $ret"
                   iteration_end $target $cnt $cnt_max $mnt
                   continue
               fi
    
               echo "Done making plfs"

               # and run plfs
        
               echo "Attempting to run newly compiled plfs"
#               plfs_ret=`/users/atorrez/Testing/regression/inst/plfs/sbin/plfs 2>&1`
               plfs_ret=`./fuse/plfs 2>&1`
               if [ "$plfs_ret" != "fuse: missing mountpoint parameter" ]; then
                 echo "ERROR Attempting to run plfs did not produce desired results"
               else 
                 echo "Successfully ran plfs"
               fi
#               ./fuse/plfs 
#               echo "Running plfs"
#               echo $mount_points

               # get pid for fuse mount 
               pid=`ps aux | grep $USER | grep $mnt | grep -v grep | awk '{print $2}'`
               echo "PID for fuse mount is $pid"

               # get number of file descriptors for fuse mount
               # and maks sure number has not changed since the last build
               proc_cnt=`ls /proc/$pid/fd | wc -l`

               # get initialize process count on 1st iteration
               if [ $cnt==1 ]; then
                 fd_prev_cnt=$proc_cnt
               fi

               if [ $proc_cnt != $fd_prev_cnt ]; then
                 echo "ERROR file_desciptor count mismatch current proc_cnt=$proc_cnt"
                 echo "ERROR process count = $proc_cnt previous count = $fd_prev_cnt"
               else 
                 echo "File descriptor count = $proc_cnt"
               fi 
               fd_prev_cnt=$proc_cnt

               # look at OpenFiles from plfsdebug and make sure count has not grown
               cat $mnt/.plfsdebug > /users/$user/tmp_plfsdebug 
               open_files=`strings /users/$user/tmp_plfsdebug | grep OpenFiles | awk '{print $1}'`
               echo ".plfsdebug reports $open_files open files"
               if [ $open_files != 0 ]; then 
                 echo "ERROR open file count not 0"
               fi

               # Clean up
               iteration_end $target $cnt $cnt_max $mnt

           done # end while loop over iterations
           echo "Removing plfs tarball and directory from $target"

           # Get out of the mount point directory
           cd

           # Unmount if need be
           if [ "$need_to_umount" == "True" ]; then
             echo "Running $base_dir/tests/utils/rs_plfs_fuse_umount.sh $mnt serial"
             $basedir/tests/utils/rs_plfs_fuse_umount.sh $mnt serial
           fi
           echo "Completed fd checks on type $io_pattern $mnt mount point"
        done #end inner for loop over mount points
    else 
        echo "ERROR $mount_points"
    fi # end if found mount points with query
done #for loop over n-n an n-1 mount points
