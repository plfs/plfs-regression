#!/bin/bash

# Variable initialization

# Define temp directories for fuse mount and backends
user=`echo ${USER}`
tmp_dir="/tmp/$user"
base_dir="$tmp_dir/tmp_plfsrc"
mount_dir="$base_dir/scratch1"
nn_mount_dir="$base_dir/scratch1_nn"
n1_mount_dir="$base_dir/scratch1_n1"
backend_dir="$tmp_dir/backend"
export PLFSRC=$base_dir/.plfsrc

current_dir=`pwd`
echo "Current directory=$current_dir"
machine_file_dir="plfsrc_files"
echo "temp directory to hold plfsrc files = $base_dir"
echo "plfsrc test files = $machine_file_dir"

#******************************************************************************
# This function verifies that the output of plfs_check_config matches 
# the expected output based on the plfsrc file set in the users
# home space
#
function verify_plfsrc {
   return_val=0
   # Check if plfs_check_config successful
   plfsrc_status=`grep SUCCESS $base_dir/test1.out`
   if [ $? == 0 ]; then
     echo "plfsrc status:  SUCCESS"
   else
     echo "Error plfsrc status:  $plfsrc_status"
     return_val=1
   fi
   backend_count=`grep Backend: $base_dir/test1.out | wc -l`
   # Check if backend count equals expected value
   if [ $backend_count -eq $backendcnt_baseline ]; then
     echo "backend count of $backend_count is correct"
   else
     echo "Error backend_cnt of $backend_count does not match etc-based $backendcnt_baseline"
     return_val=1
   fi

   #
   # Verify that plfs_check_config  Backends cnt=X matches baseline backend count
   #
   backends_count=`grep Backends $base_dir/test1.out| sed 's/=/ /g' | awk '{sum+=$3} END {print sum}'`

   # Check if backend count equals expected value
   if [ $backends_count -eq $backendcnt_baseline ]; then
     echo "backend count of $backend_count is correct (plfs_check_config total Backends cnt=$backends_count)"
   else
     echo "Error backend_cnt of $backend_count does not match etc-based $backendcnt_baseline"
     return_val=1
   fi
   
   # Check if mount_point matches expected mountpoint 
   if [ $two_mounts == 1 ]; then
     mount1=`grep 'Mount Point' $base_dir/test1.out | head -1 |  awk '{print $3}'`
     mount2=`grep 'Mount Point' $base_dir/test1.out | tail -1 |  awk '{print $3}'`
     if [ $mount1 == $mount1_baseline ]; then
       echo "mount of $mount1 is correct"
     else 
       echo "Error mount mismatch $mount1 != $mount1_baseline"
       return_val=1
     fi
     if [ $mount2 == $mount2_baseline ]; then
       echo "mount of $mount2 is correct"
     else 
       echo "Error mount mismatch $mount2 != $mount2_baseline"
       return_val=1
     fi
   else 
     mount=`grep 'Mount Point' $base_dir/test1.out | awk '{print $3}'`
     if [ $mount == $mount_baseline ]; then
       echo "mount of $mount is correct"
       # Check if mount_point directory exists
       if [ ! -d $mount ]; then
         echo "Error mount directoy $d does not exist"
         return_val=1
       else 
         echo "mount of $mount exists"
       fi
     else
       echo "Error mount mismatch $mount != $mount_baseline"
       return_val=1
     fi
   fi 
   # Check if hostdirs value matches expected hostdirs value 
   hostdirs=`grep 'Num Hostdirs' $base_dir/test1.out | awk '{print $3}'`
   if [ $hostdirs -eq $hostdirs_baseline ]; then
     echo "hostdirs count of $hostdirs is correct"
   else
     echo "Error backend_cnt of $hostdirs is incorrect"
     return_val=1
   fi
   
   # Check if threadpool value  matches expected threadpool value 
   threadpool=`grep Threadpool $base_dir/test1.out | awk '{print $3}'`
   if [ $threadpool -eq $thrdpool_baseline ]; then
   
     echo "threadpool count of $threadpool is correct"
   else
     echo "Error threadpool count of $threadpool is incorrect"
     return_val=1
   fi
   return $return_val
}
#******************************************************************************


#******************************************************************************
#
# The main function follows.  It is responsible for running tests that verify
# plfsrc and plfs_check_config consistency.
#
# The tests:
#
# Test 1 Verifies single mountpoint parameters using include directive
#        and plfs_check_config mkdir option for mount point
# Test 2 Verifies order of include directives 
# Test 3 Intentional bad ordering of mount point following backends
# Test 4 plfsrc file that does not use includes and file_per_proce directive
# Test 5 plfsrc file that does not use includes and shared file directive
# Test 6 plfsrc file that handles 2 mountpoints - file_per_proc and shared_file
# Test 7 plfsrc file that that has backend directory that does not exist
#        so run plfs_check_config -mkdir to create backend direcotories 
#
# As of now this test will use a specific machine/cluster directory to 
# specify plfsrc files that correspond to the specific scratch spaces for
# that machine.
##if [  ! -d $machine_file_dir ]; then
##  echo "Error:  plfsrc files do not exits for this machine"
##  exit 1
##fi

#
#  This section of code sets up the temp directories for mounts and
#  backends.  It also modifies the general plfsrc files to use the tmp
#  paths specified at the top of this file.
#


mkdir -p $mount_dir 
for i in {1..30}
do
   mkdir -p $backend_dir/vol$i/.plfs_store
done
echo $mount_dir

cp $machine_file_dir/plfsrc.threadpool_size.compute $base_dir/.

cp $machine_file_dir/plfsrc.scratch1.1 tmp_file1
sed -e "s%MOUNT%$mount_dir%" tmp_file1 > tmp_file2 
sed -e "s%BACKEND%$backend_dir%g" tmp_file2 > plfsrc.scratch1.1
mv plfsrc.scratch1.1 $base_dir/.

cp $machine_file_dir/plfsrc.scratch1.2 tmp_file1
sed -e "s%MOUNT%$mount_dir%" tmp_file1 > tmp_file2 
sed -e "s%BACKEND%$backend_dir%g" tmp_file2 > plfsrc.scratch1.2
mv plfsrc.scratch1.2 $base_dir/.


#
# Files plfsrc4-plfsrc7 do not use includes modify each file with tmp paths
#
for i in {1..7}
do
   cp $machine_file_dir/plfsrc$i tmp_file_$i
   if [ $i -lt 4 ]; then
     sed -e "s%INCLUDE%$base_dir%g" tmp_file_$i > plfsrc$i 
     mv plfsrc$i $base_dir/.
   elif [ $i -lt 6 ]; then
     sed -e "s%MOUNT%$mount_dir%" tmp_file_$i > tmp_filea
     sed -e "s%BACKEND%$backend_dir%g" tmp_filea > plfsrc$i 
     mv plfsrc$i $base_dir/.
   else 
     sed -e "s%MOUNT_NN%$nn_mount_dir%" tmp_file_$i > tmp_filea
     sed -e "s%MOUNT_N1%$n1_mount_dir%" tmp_filea > tmp_fileb
     sed -e "s%BACKEND%$backend_dir%g" tmp_fileb > plfsrc$i 
     mv plfsrc$i $base_dir/.
   fi
done

#cp ./$machine_file_dir/plfs* $base_dir/.

two_mounts=0
#
###############################################################################
# Test1 Normal /etc plfsrc and associated files + create mount point directory
###############################################################################
#
return_status=0
echo ""
echo "**********************************************"
echo "Starting test 1"
echo $PLFSRC
#
# Copy test 1 plfsrc file to .plfsrc 
#
cp $base_dir/plfsrc1 $base_dir/.plfsrc
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc1 | grep -v rpm | grep -v \# | awk '{print $2}'`
#mount_baseline=`grep mount ./$machine_file_dir/plfsrc.*1 | grep -v rpm | grep -v \# | awk '{print $2}'`
mount_baseline=$mount_dir
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc1 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep location ./$machine_file_dir/plfsrc.*1 | wc -l`
#
# Run plfs check config and direct output to file for use by verify_plfsrc 
# plfs_check_config creates mount point directory 
#
plfs_check_config -mkdir > $base_dir/test1.out
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
# Copy test 2 plfsrc file to .plfsrc 
#
cp $base_dir/plfsrc2 $base_dir/.plfsrc
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc2 | grep -v rpm | grep -v \# | awk '{print $2}'`
#mount_baseline=`grep mount ./$machine_file_dir/plfsrc.*1 | grep -v rpm | grep -v \# | awk '{print $2}'`
mount_baseline=$mount_dir
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc2 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep location ./$machine_file_dir/plfsrc.*1 | wc -l`
#
# Run plfs check config and direct output to file for use by verify_plfsrc 
#
plfs_check_config > $base_dir/test1.out
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
# Copy test 3 plfsrc file to .plfsrc 
#
cp $base_dir/plfsrc3 $base_dir/.plfsrc
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc3 | grep -v rpm | grep -v \# | awk '{print $2}'`
#mount_baseline=`grep mount ./$machine_file_dir/plfsrc.*1 | grep -v rpm | grep -v \# | awk '{print $2}'`
mount_baseline=$mount_dir
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc3 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep location ./$machine_file_dir/plfsrc.*2 | wc -l`
#
# Run plfs check config and direct output to file for use by verify_plfsrc 
#
plfs_check_config > $base_dir/test1.out
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
#
# Copy test 4 plfsrc file to .plfsrc 
#
cp $base_dir/plfsrc4 $base_dir/.plfsrc
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc4 | grep -v rpm | grep -v \# | awk '{print $2}'`
#mount_baseline=`grep mount ./$machine_file_dir/plfsrc.*1 | grep -v rpm | grep -v \# | awk '{print $2}'`
mount_baseline=$mount_dir
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc4 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep location ./$machine_file_dir/plfsrc.*1 | wc -l`
#
# Run plfs check config and direct output to file for use by verify_plfsrc 
#
plfs_check_config > $base_dir/test1.out
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
workload=`grep Workload $base_dir/test1.out | awk '{print $3}'`
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
cp $base_dir/plfsrc5 $base_dir/.plfsrc
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc5 | grep -v rpm | grep -v \# | awk '{print $2}'`
#mount_baseline=`grep mount ./$machine_file_dir/plfsrc.*1 | grep -v rpm | grep -v \# | awk '{print $2}'`
mount_baseline=$mount_dir
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc5 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep location ./$machine_file_dir/plfsrc.*1 | wc -l`
#
# Run plfs check config and direct output to file for use by verify_plfsrc 
#
plfs_check_config > $base_dir/test1.out
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
workload=`grep Workload $base_dir/test1.out | awk '{print $3}'`
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
cp $base_dir/plfsrc6 $base_dir/.plfsrc
#
# Determine expected values/settings
#
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc6 | grep -v rpm | grep -v \# | awk '{print $2}'`
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc6 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=10
#mount1_baseline="/plfs/scratch1"
#mount2_baseline="/plfs/scratch2"
#mount1_baseline=`grep mount ./$machine_file_dir/plfsrc6 | grep scratch1_n1 | grep -v rpm | grep -v \# | awk '{print $2}'`
mount1_baseline=$n1_mount_dir
#mount2_baseline=`grep mount ./$machine_file_dir/plfsrc6 | grep scratch1_nn | grep -v rpm | grep -v \# | awk '{print $2}'`
mount2_baseline=$nn_mount_dir

plfs_check_config -mkdir > $base_dir/test1.out

# 
# Check if Successful plfs_check_config 
#
plfsrc_status=`grep SUCCESS $base_dir/test1.out`
if [ $? == 0 ]; then
  echo "plfsrc status:  SUCCESS"
else
  echo "Error plfsrc status:  $plfsrc_status"
  return_val=1
fi
##plfsrc_status=`grep ERROR $base_dir/test1.out`
##if [ $plfsrc_status == "ERROR" ]; then
##  echo "plfsrc status:  SUCCESS"
##else
##  echo "Error plfsrc status:  $plfsrc_status"
##  return_status=1
##fi

#
# Determine if correct number of backends determined
#
backend_count1=`cat $base_dir/test1.out | sed -n '/file_per_proc/,/Checksum/p' | grep Backend: | wc -l`
backend_count2=`cat $base_dir/test1.out | sed -n '/shared_file/,/Checksum/p' | grep Backend: | wc -l`
 
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
mountpoint_cnt=`grep 'Num Mountpoints' $base_dir/test1.out | awk '{print $3}'`

if [ $mountpoint_cnt -eq 2 ]; then
  echo "Mount point count of $mountpoint_cnt is correct"
else 
  echo "Error Mountpoint count should be 2 but is $mountpoint_cnt"
  return_status=1
fi
   
#
# Determine if mountpoints match
# 
mount1=`grep 'Mount Point' $base_dir/test1.out | head -1 | awk '{print $3}'`
mount2=`grep 'Mount Point' $base_dir/test1.out | tail -1 | awk '{print $3}'`

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
hostdirs=`grep 'Num Hostdirs' $base_dir/test1.out | awk '{print $3}'`
if [ $hostdirs -eq $hostdirs_baseline ]; then
  echo "hostdirs count of $hostdirs is correct"
else
  echo "Error backend_cnt of $hostdirs is incorrect"
  return_status=1
fi
  
#
# Determine if threadpool count correct
# 
threadpool=`grep Threadpool $base_dir/test1.out | awk '{print $3}'`
if [ $threadpool -eq $thrdpool_baseline ]; then

  echo "threadpool count of $threadpool is correct"
else
  echo "Error threadpool count of $threadpool is incorrect"
  return_status=1
fi
#
# Determine if Workloads match
#
workload1=`grep 'Workload file_per_proc' $base_dir/test1.out | awk '{print $3}'`
workload2=`grep 'Workload shared_file' $base_dir/test1.out | awk '{print $3}'`

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
#
###############################################################################
# Test7 plfsrc that contains backend that needs directory creation 
###############################################################################
#
echo "**********************************************"
echo "Starting test 7"
thrdpool_baseline=`grep threadpool ./$machine_file_dir/plfsrc7 | grep -v rpm | grep -v \# | awk '{print $2}'`
#mount1_baseline=`grep mount ./$machine_file_dir/plfsrc7 | grep scratch1_n1 | grep -v rpm | grep -v \# | awk '{print $2}'`
#mount2_baseline=`grep mount ./$machine_file_dir/plfsrc7 | grep scratch1_nn | grep -v rpm | grep -v \# | awk '{print $2}'`
mount1_baseline=$n1_mount_dir
mount2_baseline=$nn_mount_dir
two_mounts=1
hostdirs_baseline=`grep num_hostdirs ./$machine_file_dir/plfsrc7 | grep -v \# | awk '{print $2}'`
backendcnt_baseline=`grep location ./$machine_file_dir/plfsrc7 | wc -l`

cp $base_dir/plfsrc7 $base_dir/.plfsrc 

#
# Run plfs check config and direct output to file for use by verify_plfsrc 
#
plfs_check_config -mkdir > $base_dir/test1.out
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
# Now check if directories truly exist 
#
dir_1=`grep xx $base_dir/plfsrc7 | sed 's/,/ /g' | awk '{print $4}' | head -1`

echo $dir_1
if [ ! -d $dir_1 ]; then
  echo "Error:  $dir_1 was not created"
  return_status=1
fi
dir_2=`grep xx $base_dir/plfsrc7 | sed 's/,/ /g' | awk '{print $4}' | tail -1`
if [ ! -d $dir_2 ]; then
  echo "Error:  $dir_2 was not created"
  return_status=1
fi

echo "Done with test 7"
echo "**********************************************"
echo ""


unset PLFSRC

echo "Removing tmp directory"
rm -rf $tmp_dir
rm -f tmp_file*

exit $return_status

#******************************************************************************
