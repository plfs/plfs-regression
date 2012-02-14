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
# Loop over each of the PLFS mount points defined in the plfsrc file.
#
foreach mnt ( $mount_points )
#
# Check to see if $mnt is already mounted. If it is not, and it can't be mounted
# successfully, print an error and return a non-zero value to note the error.
#
#  set the_mp = `df | grep ${mnt} | awk '{print $6}'`
#  if ( $the_mp != $mnt ) then
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
#  endif
#
# Set the place where we will create a file to change ownership on, and get the
# groups to which this user belongs.
#
  set top  = $mnt/$USER
  set ts   = `date +%s`
  set file = $top/foo.$ts
  set user_groups = `groups`
#
# Make the directory where we will ccreate the file on which ownership will be changed
# and make sure that's successful.
#
  echo "Making directory $top with mkdir -p..."
  mkdir -p $top
  if ( $? != 0 ) then
    echo "Failure: Error making directory $top with mkdir -p"
    exit 1
  endif
#
# Create the file on which ownership will be changed.
#
  echo "Creating file $file with touch..."
  touch $file
  if ( $? != 0 ) then
    echo "Failure: Error creating file $file with touch"
    exit 1
  endif
#
# Figure out to which group the file just created belongs.
#
  set file_group = `ls -lt $file | awk '{print $4}'`

  echo "Going to change the group of file $file to a group different than $file_group..."
#
# Now loop over the groups to which this user belongs.
#
  foreach ug ( $user_groups )

    echo "Evaluating group $ug..."
#
# Find a group to which this user belongs that is different than the group
# to which the file belongs, change the file's group to a different group,
# and make sure the group was changed.
#
    if ( $ug != $file_group ) then
      chown $USER.$ug $file
      set new_group = `ls -lt $file | awk '{print $4}'`

#      echo "Attempted to change the group of file $file from $file_group to $new_group"

      if ( $new_group != $ug ) then
        echo "Failure: The new group is the same as the original group."
        exit 1
      endif

      echo "Success: Changed the group of file $file from $file_group to $new_group"
      break
    endif
  end
#
# Get rid of the file we created and on which we changed the group
#
  echo "Removing file $file..."
  rm $file
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
end
