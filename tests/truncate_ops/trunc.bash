#!/bin/bash
source /users/atorrez/iotests/regression//tests/utils/rs_env_init.sh


compile_out=`mpicc -o truncate truncate.c`
if [ $? == 0 ]; then
    echo "truncate.c compiled successfully"
else
    echo "Error:  Problem compiling c"
    exit 1
fi


if [ -x ../utils/rs_plfs_config_query.py ]; then
  mount_points=`../utils/rs_plfs_config_query.py -m`
#
# If the script fails, note that and return a non-zero value.
#
  if [ $? != 0 ]; then
    echo "Failure: Error finding the PLFS mount points with rs_plfs_config_query.py"
    exit 1
  fi 
#
# Got the mount points parsed from the plfsrc file.
#
  echo "PLFS mount point(s) is/are: $mount_points"
#
# The script was not found or is not executable.
#
else
  echo "Failure: The script, ../utils/rs_plfs_config_query.py, is not executable and must be"
  exit 1
fi

#
# Loop through all mount points
#
nto1_mnt_cnt=`plfs_check_config | grep N-1 | wc -l`
if [ $nto1_mnt_cnt -ge 1 ]; then
for mnt in $mount_points
do
  echo ""
  echo "Using $mnt for truncate test"
  nto1_mount=`plfs_check_config | grep -A 1 /var/tmp/plfs.atorrez | grep -B 1 N-1 | head -1 | awk '{print $3}'`
  if [ $mnt == $nto1_mount ]; then
#
# Mount the defined mount point
#
  ../utils/rs_plfs_fuse_mount.sh $mnt serial
  ret=$?
  echo "XX $ret"
  if [ $ret == 0 ]; then
     need_to_unmount=1
  elif [ $ret == 1 ]; then
     need_to_unmount=0
  else
    echo "Failure: Mount point $mnt is not mounted and could not be mounted by $USER"
    exit 1
  fi 


#
# Append user name to mount
  target=`../utils/rs_exprmgmtrc_target_path_append.py $mnt`
#
  echo "going to call C truncate program"
  return_value=0;
#
# Call dir_ops to create and remove directories and files
#
  ./truncate $target/tmp.txt 
  if [ $? == 1 ]; then
    return_value=1
  fi 
#
# Unmount if necessary
#
  echo "Going to unmount $mnt now $need_to_unmount"
  if [ $need_to_unmount == 1 ]; then
    ../utils/rs_plfs_fuse_umount.sh $mnt serial
    if [ $? != 0 ]; then
      echo "Failure: Mount point $mnt could not be unmounted by $USER"
      exit 1
    fi 
  fi 
  fi
done
else
    echo "Error:  Test requires shared_file (N-1) mount point but none found"
    exit 1
fi
exit $return_value
