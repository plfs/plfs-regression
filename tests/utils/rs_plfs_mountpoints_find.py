#!/usr/bin/env python
#
# Common functions related to mount points

import subprocess

def get_mountpoints():
    """Determine plfs mount points by calling plfs_check_config.
    """
    mount_points = []
    ps = subprocess.Popen(['plfs_check_config'], stdin=None, 
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    output = ps.communicate()
    if ps.returncode != 0:
        print ("Error: plfs_check_config returned with exit code " 
            + str(ps.returncode))
        print ("Standard output from plfs_check_config:")
        print str(output[0])
        print ("Standard error from plfs_check_config:")
        print str(output[1])
    else:
        # Split stdout into lines and loop over them, looking for lines
        # with mount points in them.
        stdout = output[0].split('\n')
        for line in stdout:
            if ("Mount Point" in line):
                # The path to the mount point should be the last element on the line
                mp = (line.split())[-1]
                # Remove the trailing ':' and append to the mount points list
                mount_points.append(mp[:-1])

    if len(mount_points) == 0:
        print ("Error: no mount points will be passed back. Either the rc "
            + "files had no mount points in them or there was a problem "
            + "parsing them.")

    return mount_points
