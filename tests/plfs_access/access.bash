#!/bin/bash
source ../utils/rs_env_init.sh

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

flags=`../utils/rs_plfs_buildflags_get.py`
if [[ $? != 0 ]]; then
    exit 1
fi
rs_plfs_cflags=`echo "$flags" | head -n 1`
rs_plfs_ldflags=`echo "$flags" | tail -n 1`
echo "PLFS linking flags = ${rs_plfs_ldflags}"
echo "PLFS compile flags = ${rs_plfs_cflags}"
echo "Going to compile access.c"
#compile_out=`gcc -o access -I /users/atorrez/Testing/regression/inst/plfs/include -L /usr/projects/plfs/rrz/plfs/gcc-system/plfs-2.2.1/install/lib -lplfs -lpthread access.c`
compile_out=`gcc -o access ${rs_plfs_cflags} ${rs_plfs_ldflags} access.c`
if [ $? == 0 ]; then
    echo "access.c compiled successfully"
else
    echo "Error:  Problem compiling access.c"
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
  path_cnt=`echo $mnt | sed -e 's/\// /g' | wc -w`
#
# Get the directory depth for mount and appended username
#
  echo "Mountpoint directory depth is $path_cnt"
  x=1
#
# Break the full directoy into chunks as follows
#
# if full directory = /dir_1/dir_2/dir_3
#
# then it is broken up as follow:
# /dir_1  /dir_1/dir_2  /dir_1/dir_2/dir_3
# so that plfs_access can run on each of these
#
  while [ $x -le $path_cnt ]
  do
#
# define column as the chunks defined above
#
     if [ "$x" == 1 ]; then
        column="\$1"
     elif [ "$x" ==  2 ]; then
        column="\$1\$2"
     elif [ "$x" == 3 ]; then
        column="\$1\$2\$3"
     fi
#
# Based on on loop count, determine directory to run plfs_access   
#
     echo "Doing test on depth = $x"
     dir=`echo $mnt | sed -e 's/\// \//g' | awk '{print '$column'}'`
     x=$(( $x + 1 ))
     echo "Directory for test = $dir"
#
# Run plfs_acess on the directory
#
     run_plfs_access $dir 0 
     if [[ $? == 0 ]]; then
         return_value=0
     else
         return_value=1
     fi
  done
#
# Run plfs_acess on the  mount + appended directory 
#
  run_plfs_access $target 0
  if [[ $? == 0 ]]; then
     return_value=0
  else
     return_value=1
  fi
  bad_dir="$target/nonexistent_dir"
#
# Run plfs_acess on the  mount + invalid directory 
#
  run_plfs_access $bad_dir -2 
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
      exit 1
    fi 
  fi 
done
exit $return_value
