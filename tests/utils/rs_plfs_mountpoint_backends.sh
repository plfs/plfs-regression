#!/bin/bash
#
# Run the plfs_check_config program. It reads the plfsrc file to find
# the mount points and their backends. We need our mount point and
# its backends. The backend lines immediately follow the mount point
# line until there's a checksum line.
#
# If the mount point is not found then an empty list of backends is returned.
#
#
# Here's an example output:
#
#Config file correctly parsed:
#Num Hostdirs: 32
#Threadpool size: 1
#Write index buffer size (mbs): 64
#Num Mountpoints: 2
#Mount Point /plfs/scratch2:
#	Backend: /panfs/scratch2/vol1/.plfs_store
#	Backend: /panfs/scratch2/vol2/.plfs_store
#	Backend: /panfs/scratch2/vol3/.plfs_store
#	Backend: /panfs/scratch2/vol4/.plfs_store
#	Checksum: 12294
#Mount Point /plfs/scratch3:
#	Backend: /panfs/scratch3/vol1/.plfs_store
#	Backend: /panfs/scratch3/vol2/.plfs_store
#	Backend: /panfs/scratch3/vol3/.plfs_store
#	Backend: /panfs/scratch3/vol4/.plfs_store
#	Backend: /panfs/scratch3/vol5/.plfs_store
#	Backend: /panfs/scratch3/vol6/.plfs_store
#	Backend: /panfs/scratch3/vol7/.plfs_store
#	Backend: /panfs/scratch3/vol8/.plfs_store
#	Backend: /panfs/scratch3/vol9/.plfs_store
#	Backend: /panfs/scratch3/vol10/.plfs_store
#	Backend: /panfs/scratch3/vol11/.plfs_store
#	Backend: /panfs/scratch3/vol12/.plfs_store
#	Checksum: 37147
#SUCCESS
#

#
# Make sure that there is an argument to this script that is supposed
# to be a mount point for which we'll find the backends.
#
#echo "Argument count is $#"
if [ $# != 1 ]; then
  echo "Failure: No mountpoint argument. Usage: rs_plfs_mountpoint_backends.sh <mount-point>"
  exit 1
fi

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
  $pcc > pcc.out
else
  echo "Failure: Cannot find a plfs_check_config executable"
  exit 1
fi

#
# Now the file pcc.out contains zero or more lines each of the format:
#
#   Mount Point <path>:
#
# each followed by one or more lines each of the format:
#
#   Backend: <path>
#
be_count=0
mp="Undefined"
while read line    
do    
#
# If the first word of the line is "Mount", then we have a mount point line.
#
  keyword="`echo $line | awk '{print $1}'`"
#  echo $keyword

  case "$keyword" in
    Mount)
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
#      echo "$mp"    
      ;;
    Backend:)
#
# Now we want to know if the mount point we've found is the one we are
# looking for.
#
      if [ $mp = $1 ]; then
        be="`echo $line | awk '{print $2}'`"

        (( be_count += 1 ))

        if [ $be_count = 1 ]; then
          mount_point_backends=$be
        else
          mount_point_backends="$mount_point_backends $be"
        fi
      fi
      ;;
    *)
#
# If we already found the mount point in question and got to another line after
# the "Backend:" lines, then we're done.
#
      if [ $mp = $1 ]; then
        break
      else
        continue
      fi
      ;;
  esac
done <pcc.out

#
# Get rid of the temporary file we used for the output of plfs_check_config
#
rm -f pcc.out

#
# Output the space-delimted string of mount point backends for the caller to
# get and use.
#
echo $mount_point_backends
