#!/bin/bash

# Variable initialization
base_dir=${HOME}
current_dir=`pwd`
echo "Home directory=$HOME
echo "Current directory=$current_dir
tmp_dir="tmp_dir_for_regression_plfsrc"
target_tmp_dir=$base_dir/$tmp_dir
hostname=`echo $HOSTNAME | sed 's/-/ /' | awk '{print $1}'`
echo $hostname
machine_file_dir=$hostname"_plfsrc_files"
echo "temp directory to hold plfsrc files = $target_tmp_dir"
echo "plfsrc test files = $machine_file_dir"
user=`echo $USER`

#
# This function verifies that the output of plfs_check_config matches 
# the expected output based on the plfsrc file set in the users
# home space
#
function verify_plfsrc {
   return_val=0
   # Check if plfs_check_config successful
   plfsrc_status=`grep SUCCESS $target_tmp_dir/test1.out`
   if [ $plfsrc_status == "SUCCESS" ]; then
     echo "plfsrc status:  SUCCESS"
   else
     echo "Error plfsrc status:  $plfsrc_status"
     return_val=1
   fi
   backend_count=`grep Backend $target_tmp_dir/test1.out | wc -l`
   
   # Check if backend count equals expected value
   if [ $backend_count -eq $backendcnt_baseline ]; then
     echo "backend count of $backend_count is correct"
   else
     echo "Error backend_cnt of $backend_count does not match etc-based $backendcnt_baseline"
     return_val=1
   fi
   
   # Check if mount_point matches expected mountpoint 
   mount=`grep 'Mount Point' $target_tmp_dir/test1.out | awk '{print $3}'`
   if [ $mount == $mount_baseline ]; then
     echo "mount of $mount is correct"
   else
     echo "Error mount mismatch $mount != $mount_baseline"
     return_val=1
   fi
   
   # Check if hostdirs value matches expected hostdirs value 
   hostdirs=`grep 'Num Hostdirs' $target_tmp_dir/test1.out | awk '{print $3}'`
   if [ $hostdirs -eq $hostdirs_baseline ]; then
     echo "hostdirs count of $hostdirs is correct"
   else
     echo "Error backend_cnt of $hostdirs is incorrect"
     return_val=1
   fi
   
   # Check if threadpool value  matches expected threadpool value 
   threadpool=`grep Threadpool $target_tmp_dir/test1.out | awk '{print $3}'`
   if [ $threadpool -eq $thrdpool_baseline ]; then
   
     echo "threadpool count of $threadpool is correct"
   else
     echo "Error threadpool count of $threadpool is incorrect"
     return_val=1
   fi
   return $return_val
}


#
# The main function follows.  It is responsible for running tests that verify
# plfsrc and plfs_check_config consistency.
#
# The tests:
#
# Test 1 Verifies single mountpoint parameters using include directive
# Test 2 Verifies order of include directives 
# Test 3 Intentional bad ordering of mount point following backends
# Test 4 plfsrc file that does not use includes and file_per_proce directive
# Test 5 plfsrc file that does not use includes and shared file directive
# Test 6 plfsrc file that handles 2 mountpoints - file_per_proc and shared_file
#
# As of now this test will use a specific machine/cluster directory to 
# specify plfsrc files that correspond to the specific scratch spaces for
# that machine.
if [  ! -d $machine_file_dir ]; then
  echo "Error:  plfsrc files do not exits for this machine"
  exit 1
fi
#
#Save currently loaded plfsrc files in a newly created temp directory 
#
if [ -d $target_tmp_dir ]; then
   echo "Error: directory exists"
   echo "Please remove tmp_dir_for_regression_plfsrc directory from: "
   echo "$base_dir"
   echo "then run again"
   exit 1;
else 
   echo "directory does not exist so need to create now"
   mkdir $target_tmp_dir
   if [ $? == 0 ]; then
      echo "Directory created"
      for i in `ls $base_dir/plfsrc* $base_dir/.plfsrc*`
      do
         echo "$i is going to be copied to $base_dir/tmp_dir_for_regression_plfsrc"
         cp $i $target_tmp_dir/.
      done
     
   else 
      echo "Error Directory cannot be created"
      exit 1;
   fi
fi  
#
# Copy the current plfsrc files to a temp directory
#
cp ./$machine_file_dir/plfs* $base_dir/.

#
###############################################################################
# Test1 Normal /etc plfsrc and associated files
###############################################################################
#
return_status=0
echo ""
echo "**********************************************"
echo "Starting test 1"
#
# Make plfsrc file unique to user (path)
#
cp $machine_file_dir/plfsrc1 tmp_plfsrc1 
cat ./tmp_plfsrc1 | sed "s/XXXX/${user}/" > ./plfsrc1
mv ./plfsrc1 $base_dir/.plfsrc 
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc.* | grep -v rpm | grep -v \# | awk '{print $2}'`
mount_baseline=`grep mount ./$machine_file_dir/plfsrc.*1 | grep -v rpm | grep -v \# | awk '{print $2}'`
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc1 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep backend ./$machine_file_dir/plfsrc.*1 | grep -v rpm | sed 's/[^,]//g' | wc -m`
#
# Run plfs check config and direct output to file for use by verify_plfsrc 
#
plfs_check_config > $target_tmp_dir/test1.out
#
# Determine if error using plfs_check config
#
if [ $? == 1 ]; then
    echo "ERROR DETECTED using plfs_check_config"
    return_status=1
#
# Else no error call verify_plfsrc
#
else 
    verify_plfsrc
    if [ $? == 1 ]; then
        return_status=1
    fi
fi
echo "Done with test 1"
echo "**********************************************"
echo ""
#
###############################################################################
# Test2 /etc/plfsrc with order of includes changed threadpool, scratch1 and 
# num_hostdirs in that order
###############################################################################
#
echo "**********************************************"
echo "Starting test 2"
#
# Make plfsrc file unique to user (path)
#
cp $machine_file_dir/plfsrc2 tmp_plfsrc2 
cat ./tmp_plfsrc2 | sed "s/XXXX/${user}/" > ./plfsrc2
mv ./plfsrc2 $base_dir/.plfsrc 
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc.* | grep -v rpm | grep -v \# | awk '{print $2}'`
mount_baseline=`grep mount ./$machine_file_dir/plfsrc.*2 | grep -v rpm | grep -v \# | awk '{print $2}'`
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc2 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep backend ./$machine_file_dir/plfsrc.*2 | grep -v rpm | sed 's/[^,]//g' | wc -m`
#
# Run plfs check config and direct output to file for use by verify_plfsrc 
#
plfs_check_config > $target_tmp_dir/test1.out
if [ $? == 1 ]; then
    echo "ERROR DETECTED using plfs_check_config"
    return_status=1
#
# Else no error call verify_plfsrc
#
else
    verify_plfsrc
    if [ $? == 1 ]; then
        return_status=1
    fi
fi
echo "Done with test 2"
echo "**********************************************"
echo ""
#
###############################################################################
# Test3 include file has mount point listed after backends
###############################################################################
#
echo "**********************************************"
echo "Starting test 3"
#
# Make plfsrc file unique to user (path)
#
cp $machine_file_dir/plfsrc3 tmp_plfsrc3 
cat ./tmp_plfsrc3 | sed "s/XXXX/${user}/" > ./plfsrc3
mv ./plfsrc3 $base_dir/.plfsrc 
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc.* | grep -v rpm | grep -v \# | awk '{print $2}'`
mount_baseline=`grep mount ./$machine_file_dir/plfsrc.*3 | grep -v rpm | grep -v \# | awk '{print $2}'`
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc3 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep backend ./$machine_file_dir/plfsrc.*3 | grep -v rpm | sed 's/[^,]//g' | wc -m`
#
# Run plfs check config and direct output to file for use by verify_plfsrc 
#
plfs_check_config > $target_tmp_dir/test1.out
if [ $? != 0 ]; then
    echo "Test succcessfully detected ERROR when using plfs_check_config"
#
# Else no error call verify_plfsrc
#
else
    return_status=1
fi
echo "Done with test 3"
echo "**********************************************"
echo ""
#
###############################################################################
# Test4 good plfsrc that does not use includes workload file_per_proc
###############################################################################
#
echo "**********************************************"
echo "Starting test 4"
mv $base_dir/plfsrc4 $base_dir/.plfsrc
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc.* | grep -v rpm | grep -v \# | awk '{print $2}'`
mount_baseline=`grep mount ./$machine_file_dir/plfsrc.*4 | grep -v rpm | grep -v \# | awk '{print $2}'`
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc3 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep backend ./$machine_file_dir/plfsrc.*4 | grep -v rpm | sed 's/[^,]//g' | wc -m`
#
# Run plfs check config and direct output to file for use by verify_plfsrc 
#
plfs_check_config > $target_tmp_dir/test1.out
if [ $? == 1 ]; then
    echo "ERROR DETECTED using plfs_check_config"
    return_status=1
#
# Else no error call verify_plfsrc
#
else
    verify_plfsrc
    if [ $? == 1 ]; then
        return_status=1
    fi
fi
#
# Deterime if correct workload found
#
workload=`grep Workload $target_tmp_dir/test1.out | awk '{print $3}'`
echo $workload
if [ $workload == "file_per_proc" ]; then
   echo "workload of $workload is correct"
else
   echo "Error workload of $workload is incorrect"
   return_status=1
fi
echo "Done with test 4"
echo "**********************************************"
echo ""
#
###############################################################################
# Test5 good plfsrc that does not use includes workload shared_file 
###############################################################################
#
echo "**********************************************"
echo "Starting test 5"
mv $base_dir/plfsrc5 $base_dir/.plfsrc
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc.* | grep -v rpm | grep -v \# | awk '{print $2}'`
mount_baseline=`grep mount ./$machine_file_dir/plfsrc.*4 | grep -v rpm | grep -v \# | awk '{print $2}'`
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc3 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep backend ./$machine_file_dir/plfsrc.*4 | grep -v rpm | sed 's/[^,]//g' | wc -m`
#
# Run plfs check config and direct output to file for use by verify_plfsrc 
#
plfs_check_config > $target_tmp_dir/test1.out
if [ $? == 1 ]; then
    echo "ERROR DETECTED using plfs_check_config"
    return_status=1
#
# Else no error call verify_plfsrc
#
else
    verify_plfsrc
    if [ $? == 1 ]; then
        return_status=1
    fi
fi
#
# Deterime if correct workload found
#
workload=`grep Workload $target_tmp_dir/test1.out | awk '{print $3}'`
echo $workload
if [ $workload == "shared_file" ]; then
   echo "workload of $workload is correct"
else
   echo "Error workload of $workload is incorrect"
   return_status=1
fi
echo "Done with test 5"
echo "**********************************************"
echo ""
#
###############################################################################
# Test6 plfsrc that includes two mountpoints and two different workloads
###############################################################################
#
echo "**********************************************"
echo "Starting test 6"
mv $base_dir/plfsrc6 $base_dir/.plfsrc
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc.* | grep -v rpm | grep -v \# | awk '{print $2}'`
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc3 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=10
mount1_baseline="/plfs/scratch1"
mount2_baseline="/plfs/scratch2"

plfs_check_config > $target_tmp_dir/test1.out

# 
# Check if Successful plfs_check_config 
#
plfsrc_status=`grep ERROR $target_tmp_dir/test1.out`
if [ $plfsrc_status == "ERROR" ]; then
  echo "plfsrc status:  SUCCESS"
else
  echo "Error plfsrc status:  $plfsrc_status"
  return_status=1
fi

#
# Determine if correct number of backends determined
#
backend_count1=`cat $target_tmp_dir/test1.out | sed -n '/file_per_proc/,/Checksum/p' | grep Backend | wc -l`
backend_count2=`cat $target_tmp_dir/test1.out | sed -n '/shared_file/,/Checksum/p' | grep Backend | wc -l`
 
if [[ $backend_count1 -eq $backendcnt_baseline && 
      $backend_count2 -eq $backendcnt_baseline ]]; then
  echo "backend count of $backend_count is correct"
else
  echo "Error backend_cnt of $backend_count does not match etc-based $backendcnt_baseline"
  return_status=1
fi
#
# Determine if correct number of mountpoints found
#
mountpoint_cnt=`grep 'Num Mountpoints' $target_tmp_dir/test1.out | awk '{print $3}'`

if [ $mountpoint_cnt -eq 2 ]; then
  echo "Mount point count of $mountpoint_cnt is correct"
else 
  echo "Error Mountpoint count should be 2 but is $mountpoint_cnt"
  return_status=1
fi
   
#
# Determine if mountpoints match
# 
mount1=`grep 'Mount Point' $target_tmp_dir/test1.out | head -1 | awk '{print $3}'`
mount2=`grep 'Mount Point' $target_tmp_dir/test1.out | tail -1 | awk '{print $3}'`

if [[ $mount1 == $mount1_baseline && $mount2 == $mount2_baseline ]]; then
  echo "mount of $mount1 is correct"
  echo "mount of $mount2 is correct"
else
  echo "Error mount mismatch $mount1 != $mount1_baseline or"
  echo "Error mount mismatch $mount2 != $mount2_baseline"
  return_status=1
fi
#
# Determine if  number of hostdirs correct
# 
hostdirs=`grep 'Num Hostdirs' $target_tmp_dir/test1.out | awk '{print $3}'`
if [ $hostdirs -eq $hostdirs_baseline ]; then
  echo "hostdirs count of $hostdirs is correct"
else
  echo "Error backend_cnt of $hostdirs is incorrect"
  return_status=1
fi
  
#
# Determine if threadpool count correct
# 
threadpool=`grep Threadpool $target_tmp_dir/test1.out | awk '{print $3}'`
if [ $threadpool -eq $thrdpool_baseline ]; then

  echo "threadpool count of $threadpool is correct"
else
  echo "Error threadpool count of $threadpool is incorrect"
  return_status=1
fi
#
# Determine if Workloads match
#
workload1=`grep 'Workload file_per_proc' $target_tmp_dir/test1.out | awk '{print $3}'`
workload2=`grep 'Workload shared_file' $target_tmp_dir/test1.out | awk '{print $3}'`

if [[ $workload1 == "file_per_proc" && $workload2 == "shared_file" ]]; then
   echo "workload of $workload1 is correct"
   echo "workload of $workload2 is correct"
else
   echo "Error workload of $workload1 or $workload2 is incorrect"
  return_status=1
fi
echo "Done with test 6"
echo "**********************************************"
echo ""

rm -f ./tmp_plfsrc*

#
# Remove plfsrc test files from home directory
#
echo "Removing plfsrc test files from home directory"
rm -f $base_dir/.plfsrc
rm -f $base_dir/plfsrc*
#
#Copy plfsrc files from tmp directory back to home space
#
echo "Copying original plfsrc files back to home space"
cp $target_tmp_dir/* $base_dir/.
cp $target_tmp_dir/.* $base_dir/.
#
#remove tmp directory
#
echo "Removing tmp directory"
rm -rf $target_tmp_dir

exit $return_status
