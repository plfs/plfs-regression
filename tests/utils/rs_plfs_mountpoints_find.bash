#!/bin/bash

#
# Run the plfs_check_config program. It reads the plfsrc file to find
# the mount points and their backends. We only need the mount points and
# each is output on its own line
#

#
# This one seems more general, but if there is no plfs_check_config in
# PATH, then which returns an error and the script exits.
#
pcc=`which plfs_check_config`
if [ $? != 0 ]; then
  echo "Failure: Cannot find a plfs_check_config executable"
  exit 1
fi

#
# This one relies on the plfs module being loaded so that PLFS_HOME
# is defined.
#
#pcc=$PLFS_HOME/bin/plfs_check_config

if [ -x $pcc ]; then
  $pcc | grep "Mount Point" > pmps.out
else
  echo "Failure: Cannot find a plfs_check_config executable"
  exit 1
fi

#
# Now the file pmps.out contains zero or more lines each of the format:
#
#   Mount Point <path>:
#
mp_count=0
while read line    
do    

#
# Here we'll pull-out the <path> part of the Mount Point line along with
# the colon (":") at the end.
#
    mp="`echo $line | awk '{print $3}'`"
#
# We don't want the colon (":") at the end, so we'll find out how long
# the <path>: string is and take all, but the last character, the ":".
#
    len_mp=${#mp}
    mp=${mp:0:$len_mp-1}
#    echo "$mp"    

#
# Now we want to know which mount point we've found. We treat the first
# differently, we just save it by itself. Any others we want to prepend
# a space delimeter in front of them so that the user can get a space-
# delimited string of all the mount point paths to process.
#
    (( mp_count += 1 ))
#    echo $mp_count

     if [ $mp_count = 1 ]; then
       mount_points=$mp
     else
       mount_points="$mount_points $mp"
     fi
done <pmps.out

#
# Get rid of the temporary file we used for the output of plfs_check_config
#
rm -f pmps.out

#
# Output the space-delimted string of mount point paths for the caller to
# get and use.
#
echo $mount_points
