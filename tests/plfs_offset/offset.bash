#!/bin/bash
source ../utils/rs_env_init.sh

function run_plfs_offset {
     
     echo "Running plfs_offset on $1"
     `./offset $1`
      offset_result=$?
     if [ $offset_result == 0 ]; then
        echo "Correct plfs_offset return value"
        return 0
     else
        echo "Error plfs_offset invalid return value"
        echo "Test $offset_result Failed"
        return 1
     fi
}

flags=`../utils/rs_plfs_buildflags_get.py`
if [[ $? != 0 ]]; then
    exit 1
fi
rs_plfs_cflags=`echo "$flags" | head -n 1`
rs_plfs_ldflags=`echo "$flags" | tail -n 1`
echo "PLFS linking flags = ${rs_plfs_ldflags}"
echo "PLFS compile flags = ${rs_plfs_cflags}"
echo "Going to compile offset.c"
compile_out=`gcc -o offset ${rs_plfs_cflags} ${rs_plfs_ldflags} offset.c`
if [ $? == 0 ]; then
    echo "offset.c compiled successfully"
else
    echo "Error:  Problem compiling offset.c"
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
# Keep track of errors for all mounts.  If one mount fails then test fails by returning a 1
#
mnt_ret_value=0

#
# Loop through all mount points
#
for mnt in $mount_points
do
  echo ""
  echo "Using $mnt for plfs_offset test"
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
    mnt_ret_value=1
    continue
  fi 

#
# Append user name to mount
  target=`../utils/rs_exprmgmtrc_target_path_append.py $mnt`
  run_plfs_offset $target/test.out  
  if [[ $? == 0 ]]; then
    return_value=0
  else
    return_value=1
  fi 
#
# Unmount if necessary
#
  if [ $need_to_unmount == 1 ]; then
    ../utils/rs_plfs_fuse_umount.sh $mnt serial
    if [ $? != 0 ]; then
      echo "Failure: Mount point $mnt could not be unmounted by $USER"
      mnt_ret_value=1
      continue
    fi 
  fi 
done
if [ $mnt_ret_value = 1 ]; then
  exit $mnt_ret_value
else
  exit $return_value
fi
