#! /bin/tcsh -f

# For testing purposes, just use $HOME
#set mount_points  = "$HOME/plfs1 $HOME/plfs2"

#
# Make sure the script that parses out the PLFS mount points is there and that
# it is executable.
#
if ( -x ../utils/rs_plfs_config_query.py ) then
  set mount_points = `../utils/rs_plfs_config_query.py -m`
#
# If the script fails, note that and return a non-zero value.
#
  if ( $? != 0 ) then
    echo "Failure: Error finding the PLFS mount points with rs_plfs_config_query.py"
    exit 1
  endif
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
endif
#
# Check to make sure the script that will append experiment_managment's
# rs_mnt_append_path is available.
#
if ( ! -x ../utils/rs_exprmgmtrc_target_path_append.py ) then
  echo "Failure: ../utils/rs_exprmgmtrc_mnt_append_path_append.py is not executable and must be"
  exit 1
endif


#
# Get the groups associated with current user
#
set user_groups = `groups`


#
# Loop over each of the PLFS mount points defined in the plfsrc file.
#
foreach mnt ( $mount_points )
#
# Check to see if $mnt is already mounted. If it is not, and it can't be mounted
# successfully, print an error and return a non-zero value to note the error.
#
  ../utils/rs_plfs_fuse_mount.sh $mnt serial
  set ret = $?
  if ( $ret == 0 ) then
    set need_to_unmount = 1
  else if ( $ret == 1 ) then
    set need_to_unmount = 0
  else
    echo "Failure: Mount point $mnt is not mounted and could not be mounted by $USER"
    exit 1
  endif
#
# Set the place where we will create a file and change ownership
# Directory tmp directory will be created under mount point.
#
  set top_dir = `../utils/rs_exprmgmtrc_target_path_append.py $mnt`
  set sub_dir = $top_dir/tmp

#
# Make the directory where we will create a subdir (tmp), change permissions, 
# and make sure that's successful.
#
  echo "Making directory $sub_dir with mkdir -p..."
  mkdir -p $sub_dir
  if ( $? != 0 ) then
    echo "Failure: Error making directory $sub_dir with mkdir -p"
    exit 1
  endif
#
# Get permissions for tmp directory just created
#
  set perm = `ls -al $top_dir | grep tmp | awk '{print $1}'`
  echo "Initial permissons for tmp directory:  $perm"
#
# change tmp directory permissions to 777 
#
  chmod 644 $sub_dir
  set dir_group = `ls -lt $top_dir | grep tmp | awk '{print $4}'`
  echo "Permissions for tmp directory changed to:  $dir_group"

#
# Find a group that is different from the newly created tmp directory.  Once
# a new group is found, make tmp directory part of that greoup.
  foreach ug ($user_groups) 
    if ($dir_group != $ug) then
      break
    endif
  end
  
  echo "Changing group from $dir_group to $ug"
#
# Change group designation
#
  chown $USER.$ug $sub_dir
#
# Get permissions after the group change
#
  set post_perm = `ls -al $top_dir | grep tmp | awk '{print $1}'`
  echo Perimisions after group change are: $post_perm

  set tmp_dir = "/tmp"


#
# Get a list of backends for this mount point.
#
  if ( -x ../utils/rs_plfs_config_query.py ) then
    set mount_point_backends = `../utils/rs_plfs_config_query.py -b $mnt`
#
# If the script fails, note that and return a non-zero value.
#
    if (( $? != 0 ) || ( mount_point_backends == "" )) then
      echo "Failure: Error finding the PLFS mount point backends with rs_plfs_config_query.py"
      exit 1
    else
#
# Got the mount points parsed from the plfsrc file.
#
      echo "PLFS mount point $mnt backend(s) is/are: $mount_point_backends"
    endif
#
# The script was not found or is not executable.
#
  else
    echo "Failure: The script, ../utils/rs_plfs_config_query.py, is not executable and must be"
    exit 1
  endif
#
# Loop over each of the mount point backends defined in the plfsrc file.
# Verify that:
# 1)  permissions of tmp directory on backends match FUSE mount permissions
# 2)  group designation of tmp directory on backends match FUSE mount permissions
#
  set return_value = 0
  foreach backend ( $mount_point_backends )
    # Need to get the optional append path
    set backend_top_dir = `../utils/rs_exprmgmtrc_target_path_append.py $backend`
    echo "Checking to make sure that $tmp_dir exists in $backend_top_dir..."
    if ( ! -e $backend_top_dir/$tmp_dir ) then
      echo "Failure: The directory $tmp_dir does not exist on mount point $mnt's backend in $backend_top_dir, and should"
      exit 1
    else 
      # Check permissions
      set be_listing = `ls -al $backend_top_dir | grep tmp | awk '{print $1}'`
      echo "Backend permission for tmp directory = $be_listing"
      if ( $be_listing != $post_perm ) then
        echo "Failure: Backend permissions do not match mount permissions" 
        set return_value = 1
      endif
      # Check group 
      set dir_group = `ls -lt $backend_top_dir | grep tmp | awk '{print $4}'`
      echo "$backend_top_dir/tmp  group = $dir_group   FUSE mount group = $ug"
      if ( $dir_group != $ug ) then
        echo "Failure: Backend dir group doe not match fuse mount group" 
        set return_value = 1
      endif
    endif
    if ( $return_value == 1 ) then
      exit 1
    endif
  end
#
# Now unmount the mount point if it was mounted by us.
#
  if ( $need_to_unmount == "1" ) then
    ../utils/rs_plfs_fuse_umount.sh $mnt serial
    if ( $? != 0 ) then
      echo "Failure: Mount point $mnt could not be unmounted by $USER"
      exit 1
    endif
  endif
  echo "Removing Directory $sub_dir"
  rm -rf $sub_dir 
end

