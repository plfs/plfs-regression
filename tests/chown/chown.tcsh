#! /bin/tcsh -f
#
###################################################################################
# Copyright (c) 2009, Los Alamos National Security, LLC All rights reserved.
# Copyright 2009. Los Alamos National Security, LLC. This software was produced
# under U.S. Government contract DE-AC52-06NA25396 for Los Alamos National
# Laboratory (LANL), which is operated by Los Alamos National Security, LLC for
# the U.S. Department of Energy. The U.S. Government has rights to use,
# reproduce, and distribute this software.  NEITHER THE GOVERNMENT NOR LOS
# ALAMOS NATIONAL SECURITY, LLC MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR
# ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.  If software is
# modified to produce derivative works, such modified software should be
# clearly marked, so as not to confuse it with the version available from
# LANL.
# 
# Additionally, redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following conditions are
# met:
# 
#    Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
#    Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 
#    Neither the name of Los Alamos National Security, LLC, Los Alamos National
# Laboratory, LANL, the U.S. Government, nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY LOS ALAMOS NATIONAL SECURITY, LLC AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL LOS ALAMOS NATIONAL SECURITY, LLC OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
###################################################################################
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
# Check to make sure the script that will append experiment_managment's
# rs_mnt_append_path is available.
#
if ( ! -x ../utils/rs_exprmgmtrc_target_path_append.py ) then
  echo "Failure: ../utils/rs_exprmgmtrc_mnt_append_path_append.py is not executable and must be"
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
    continue
  endif
#
#  endif
#
# Set the place where we will create a file to change ownership on, and get the
# groups to which this user belongs. Make sure to check for
# experiment_managmenet's rc_mnt_append_path.
#
  set top  = `../utils/rs_exprmgmtrc_target_path_append.py $mnt`
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
    goto unmount
  endif
#
# Create the file on which ownership will be changed.
#
  echo "Creating file $file with touch..."
  touch $file
  if ( $? != 0 ) then
    echo "Failure: Error creating file $file with touch"
    goto unmount
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
        goto unmount 
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
  unmount:
  if ( $need_to_unmount == "1" ) then
    ../utils/rs_plfs_fuse_umount.sh $mnt serial
    if ( $? != 0 ) then
      echo "Failure: Mount point $mnt could not be unmounted by $USER"
      continue 
    endif
  endif
end
