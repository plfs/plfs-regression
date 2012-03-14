#!/usr/bin/env python
#
# Common variables and functions for this test

import os,re,sys,getpass

# Get the username to inject into the output target's filename
user = getpass.getuser()

# Figure out where the test is
curr_dir = os.getcwd()
basedir = re.sub('regression/tests.*', 'regression/', curr_dir)

# Add the directory that contains helper modules
utils_dir = basedir + "tests/utils"
if utils_dir not in sys.path:
    sys.path += [ utils_dir ]

# Import the needed common modules
import rs_exprmgmt_paths_add as em_p
# Add the experiment_management locations to sys.path
em_p.add_exprmgmt_paths(basedir)

# Only need 1 proc for this test.
nprocs = 1

# Import the module with functions for finding mount points.
import rs_plfs_config_query

def get_mountpoint():
    mount_points = rs_plfs_config_query.get_mountpoints()
    if len(mount_points) > 0:
        mount_point = mount_points[-1]
    else:
        mount_point = None
    return mount_point
    
