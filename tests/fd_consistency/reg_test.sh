#!/bin/bash
source /users/atorrez/Testing/regression//tests/utils/rs_env_init.sh
mount_points=`/users/atorrez/Testing/regression//tests/utils/rs_plfs_mountpoints_find.bash`
ret=$?
if [  "$ret" != 0 ]; then
    echo "Failure:  Error finding the PLFS mount points with rs_plfs_mountpoints_find.bash"
    exit 1
fi
echo "Running /users/atorrez/Testing/regression//tests/utils/rs_plfs_fuse_mount.sh /var/tmp/plfs2.atorrez serial"
need_to_umount="True"
/users/atorrez/Testing/regression//tests/utils/rs_plfs_fuse_mount.sh /var/tmp/plfs2.atorrez serial
ret=$?
if [  "$ret" == 0 ]; then
    echo "Mounting successful"
    need_to_umount="True"
elif [ "$ret" == 1 ]; then
    echo "Mount points already mounted."
    need_to_umount="False"
else
    echo "Something wrong with mounting."
    exit 1
fi
# This script is read in by reg_test.py and written to reg_test.sh.  
# The main purpose of this code is to build plfs repeatively and
# look for file descriptor leaks. 

# Initialize variables
fd_prev_cnt=4
cnt=0
#
# Number of times to build plfs (loop count)
cnt_max=1
#
build_for_mnt=1
user=${USER}
plfs_tarball_path="/usr/projects/plfs/regression_area/src/plfs"
latest_tarball=`/bin/ls -ltr $plfs_tarball_path/*.gz | /usr/bin/tail -1 | /bin/awk '{print $9}'`
plfs_tarball=`/bin/basename "$latest_tarball"` 

# get mount from mount_points 
for mnt in $mount_points 
do
  the_mp=`df | grep ${mnt} | awk '{print $6}'`
  echo $the_mp
  if [ $the_mp != $mnt ]; then
    build_for_mnt=1
  fi 

# loop cnt times building of plfs
  while [ $cnt -lt $cnt_max ]
  do
    let "cnt += 1"
    echo $cnt
    if [ $build_for_mnt -eq 1 ]; then

#setup to build plfs from tarball      
      echo "Copying $plfs_tarball_path/$plfs_tarball to $mnt/$user"
      cp $plfs_tarball_path/$plfs_tarball $mnt/$user/.
      #cp ../../plfs-2.1.tar.gz $mnt/$user.
      cd $mnt/$user 
# untar and build plfs
      echo "Untarring plfs"
      tar -xzf $plfs_tarball 
      echo "Done untarring" 
# figure out plfs directory name
      plfs_dir=`/bin/ls -al | grep drw | grep plfs | awk '{print $9}'`
      echo $plfs_dir
      echo "Changing directory to $plfs_dir" 
      cd $plfs_dir
   
# make plfs
      echo "make clean, configure, and make"
      make distclean
      ./configure
      pwd
      make -j
# and run plfs
      ./fuse/plfs 

      echo $mount_points
# get pid for fuse mount 
      pid=`ps aux | grep $USER | grep $mnt | grep -v grep | awk '{print $2}'`
      echo "PID for fuse mount is $pid"
# get number of file descriptors for fuse mount
# and maks sure number has not changed since the last build
      proc_cnt=`ls /proc/$pid/fd | wc -l`
      if [ $proc_cnt != $fd_prev_cnt ]; then
        echo "ERROR file_desciptor count mismatch"
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
    fi
  done
done
echo "Completed fd checks."
cd
if [ "$need_to_umount" == "True" ]; then
    echo "Running /users/atorrez/Testing/regression//tests/utils/rs_plfs_fuse_umount.sh /var/tmp/plfs2.atorrez serial"
    /users/atorrez/Testing/regression//tests/utils/rs_plfs_fuse_umount.sh /var/tmp/plfs2.atorrez serial
fi
