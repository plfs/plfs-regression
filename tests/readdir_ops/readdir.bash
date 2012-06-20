#!/bin/bash
source /users/atorrez/iotests/regression//tests/utils/rs_env_init.sh


function run_plfs_access {
#     access_result=`./access $dir`
     
     echo "Running plfs_access on $1"
     access_result=`./access $1`
     echo $access_result | grep ': '$2''
     if [ $? == 0 ]; then
        echo "Correct plfs_access return value"
        return 0
     else
        echo "Error plfs_access invalid return value"
        exit 1
     fi
}


compile_out=`gcc -o dir_ops dir_ops.c`
if [ $? == 0 ]; then
    echo "dir_ops.c compiled successfully"
else
    echo "Error:  Problem compiling c"
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
for mnt in $mount_points
do
  echo ""
  echo "Using $mnt for plfs_access test"
#
# Mount the defined mount point
#
  ../utils/rs_plfs_fuse_mount.sh $mnt serial
  ret=$?
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
  echo "going to call dir_ops"
  return_value=0;
#
# Call dir_ops to create and remove directories and files
#
  ./dir_ops $target/tmp x1
  if [ $? == 1 ]; then
    return_value=1
  fi 
#
# Unmount if necessary
#
  if [ $need_to_unmount == 1 ]; then
    ../utils/rs_plfs_fuse_umount.sh $mnt serial
    if [ $? != 0 ]; then
      echo "Failure: Mount point $mnt could not be unmounted by $USER"
      exit 1
    fi 
  fi 
done
exit $return_value
