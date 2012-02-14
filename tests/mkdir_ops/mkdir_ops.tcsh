#! /bin/tcsh -f
#
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
  if ( -x ../utils/rs_plfs_fuse_mount.sh ) then
    ../utils/rs_plfs_fuse_mount.sh $mnt serial
    set ret_val = $status
#    echo "ret_val is $ret_val"
  else
    echo "Failure: The script, ../utils/rs_plfs_fuse_mount.sh, is not executable and must be"
    exit 1
  endif

  if ( $ret_val == 0 ) then
    set need_to_unmount = 1
  else if ( $ret_val == 1 ) then
    set need_to_unmount = 0
  else
    echo "Failure: Mount point $mnt is not mounted and could not be mounted by $USER"
    exit 1
  endif
#
# endif
#
# Set the place where we will create directories to do the directory operations.
#
  set top  = $mnt/$USER

  set ts   = `date +%s`
  set dir_a = $top/a-$ts
  set ts   = `date +%s`
  set file_a = $dir_a/a.$ts
#
# Make the directory where we will do this test.
#
  echo "Making directory $top with mkdir -p..."
  mkdir -p $top
  if ( $? != 0 ) then
    echo "Failure: Error making directory $top with mkdir -p"
    exit 1
  endif
#
# Make the directory where we will create a file and make sure we can see it.
#
  echo "Making directory $dir_a with mkdir -p..."
  mkdir -p $dir_a
  if ( $? != 0 ) then
    echo "Failure: Error making directory $dir_a with mkdir -p"
    exit 1
  endif
#
# Create the file that we will verify exists.
#
  echo "Creating file $file_a with touch..."
  touch $file_a
  if ( $? != 0 ) then
    echo "Failure: Error creating file $file_a with touch"
    exit 1
  endif

  set file_name = `ls $file_a`

  if ( $file_name != $file_a ) then
    echo "Failure: The file $file_a was not found."
    exit 1
  endif
#
# Get rid of the directory and file we created.
#
  echo "Removing the directory $dir_a and the file $file_a..."
  rm -rf $dir_a
#
# Now create a directory, copy in /etc/passwd, try to remove the directory without "-rf",
# which should fail. Make sure our copy is the same as the original /etc/passwd. If
# all that succeeds, rm -rf the whole directory because it worked as expected.
#
  set ts   = `date +%s`
  set dir_p = $top/passwd-$ts
#
# Make the directory where we will copy the /etc/passwd file.
#
  echo "Making directory $dir_p with mkdir -p..."
  mkdir -p $dir_p
  if ( $? != 0 ) then
    echo "Failure: Error making directory $dir_p with mkdir -p"
    exit 1
  endif
#
# Copy in /etc/passwd and make sure that succeeds.
#
  echo "Copying /etc/passwd to $dir_p..."
  cp /etc/passwd $dir_p
  if ( $? != 0 ) then
    echo "Failure: Error copying /etc/passwd to $dir_p."
    exit 1
  endif
#
# Make sure /etc/passwd is in the dir_p.
#
  set file_name = `ls $dir_p/passwd`

  if ( $file_name != "$dir_p/passwd" ) then
    echo "Failure: The file passwd was not found in $dir_p."
    exit 1
  endif
#
# Try to remove the directory without "-rf" and while a file is in it. We should
# get an error.
#
  echo "Attempting to remove $dir_p...It should fail because the directory is not empty."
  rmdir $dir_p
  if ( $? == 0 ) then
    echo "Failure: Removed the directory $dir_p when it had a file in it and should not have removed."
    exit 1
  endif
#
# Now make sure the /etc/passwd file copied in correctly.
#
  set diff_passwd = `diff /etc/passwd $dir_p/passwd`

  if ( $diff_passwd != "" ) then
    echo "Failure: The file passwd was not copied in correctly because it is different than /etc/passwd."
    echo `diff /etc/passwd $dir_p/passwd`
    exit 1
  endif

  echo "Removing $dir_p..."
  rm -rf $dir_p
#
# Test mkdir: Use a PLFS mount with multiple backends. Create a
# directory. Use ls on the actual file system (not the PLFS mount point)
# to verify that it exists on all the backends, not just one.
#
  set ts   = `date +%s`
  set dir_e = existence-$ts
  echo "Making directory $top/$dir_e with mkdir -p..."
  mkdir -p $top/$dir_e
  if ( $? != 0 ) then
    echo "Failure: Error making directory $top/$dir_e with mkdir -p"
    exit 1
  endif
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
#
  foreach backend ( $mount_point_backends )
    echo "Checking to make sure that $dir_e exists in $backend/$USER..."
    if ( ! -e $backend/$USER/$dir_e ) then
      echo "Failure: The directory $USER/$dir_e does not exist on mount point $mnt's backend, $backend, and should"
      exit 1
    endif
  end

  echo "Removing $top/$dir_e..."
  rm -rf $top/$dir_e
#
# Now unmount the mount point if it was mounted by us.
#
  if ( $need_to_unmount == "1" ) then
    if ( -x ../utils/rs_plfs_fuse_umount.sh ) then
      ../utils/rs_plfs_fuse_umount.sh $mnt serial
      set ret_val = $status
    else
      echo "Failure: The script, ../utils/rs_plfs_fuse_umount.sh, is not executable and must be"
      exit 1
    endif

    if ( $ret_val != 0 ) then
      echo "Failure: Mount point $mnt could not be unmounted by $USER"
      exit 1
    endif
  endif
end
