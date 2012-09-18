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
build_for_mnt=1
user=${USER}

#plfs_tarball_path=`pwd`
latest_tarball=`/bin/ls -ltr $plfs_tarball_path/*.gz | /usr/bin/tail -1 | /bin/awk '{print $9}'`

if [ "$latest_tarball" == "" ]; then
  echo "Error:  No Tarball Found" 
else 
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
        echo "io_pattern $mount_points"
        echo "Running $base_dir/tests/utils/rs_plfs_fuse_mount.sh  $mount_points serial"
        need_to_umount="True"

        for mnt in $mount_points 
        do
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
              exit 1
           fi

           the_mp=`df | grep ${mnt} | awk '{print $6}'`
           echo $the_mp
           if [ $the_mp != $mnt ]; then
             build_for_mnt=1
           fi 
           target=`$base_dir/tests/utils/rs_exprmgmtrc_target_path_append.py $mnt`

           # loop cnt times building of plfs
           cnt=0
           while [ $cnt -lt $cnt_max ]
           do
             let "cnt += 1"
             echo "Test iteration $cnt on mount $mnt" 
             if [ $build_for_mnt -eq 1 ]; then

               #setup to build plfs from tarball      
               echo "Copying $plfs_tarball_path/$plfs_tarball to $target"
               cp $plfs_tarball_path/$plfs_tarball $target/.

               cd $target

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
               echo "make distclean"
               make distclean
               echo "Running configure"
               ./configure

               echo "Running make -j"
               make -j
    
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
               echo $mount_points

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
               echo ""
               echo "Completed interation $cnt of $cnt_max on $mnt"
               echo ""
             fi
           done # end while loop
           echo "Removing plfs tarball and directory from $target"

           rm -f $target/plfs.tar.gz
           rm -rf $target/plfs-2*
           cd
           if [ "$need_to_umount" == "True" ]; then
             echo "Running $base_dir/tests/utils/rs_plfs_fuse_umount.sh $mnt serial"
             $basedir/tests/utils/rs_plfs_fuse_umount.sh $mnt serial
           fi
           echo "Completed fd checks on type $io_pattern $mnt mount point"
        done #end inner for loop  
    else 
       echo "ERROR $mount_points"
    fi # end if found mount points with query
  done #for loop over n-n an n-1 mount points
fi #else endif
