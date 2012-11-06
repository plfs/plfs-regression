#!/bin/bash
#
# This script echos the first panfs scratch mount point located on the system
#
scratch_mount="`mount -t panfs | awk '{print $3}' | sed 's/\// /g' | awk '{print $2}' | head -1`"

if [ "$scratch_mount" == "" ]; then 
   echo "Error:  Unable to find panfs scratch space."
   scratch_mount="None"
else 
   if [ ! -e /$scratch_mount/$USER ]; then
       (find /panfs -maxdepth 3 -name $USER>./regression_mnt)>&/dev/null
       scratch_dir="`cat ./regression_mnt | head -1`"
       scratch_mount="`dirname $scratch_dir`"
       rm -f ./regression_mnt
   fi
fi

echo $scratch_mount
