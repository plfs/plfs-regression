#!/bin/bash
#
# This script echos the first panfs scratch mount point located on the system
#
scratch_mount="`mount -t panfs | awk '{print $3}' | sed 's/\// /g' | awk '{print $2}' | head -1`"

if [ "$scratch_mount" == "" ]; then 
   echo "Error:  Unable to find panfs scratch space."
   scratch_mount="None"
fi
echo $scratch_mount
