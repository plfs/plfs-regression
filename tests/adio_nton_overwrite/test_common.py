#!/usr/bin/env python
#
# Common functions for this regression test

import os,sys,re,getpass,commands

curr_dir = os.getcwd()
basedir = re.sub('tests/adio_nton_overwrite.*', '', curr_dir)

# Get the username to inject into the output target's filename
user = getpass.getuser()

# Add the directory that contains helper modules
utils_dir = basedir + "tests/utils"
if utils_dir not in sys.path:
    sys.path += [ utils_dir ]

# Import the needed common modules
import rs_exprmgmt_paths_add as em_p
# Add the experiment_management locations to sys.path
em_p.add_exprmgmt_paths(basedir)

# Import expr_mgmt to aid in computing how many processes we need. We want
# at least enough to cover two nodes.
import expr_mgmt
ppn = expr_mgmt.config_option_value("ppn")
nprocs = 2 * int(ppn)

# The file to use in the target to fs_test.x
file = os.getenv("MY_MPI_HOST") + ".adio_nton_overwrite"

# Import the module with functions for finding mount points.
import rs_plfs_config_query
import rs_exprmgmtrc_target_path_append as tpa

# Return a list of mount_points
def get_mountpoints():
    mount_points = rs_plfs_config_query.get_mountpoints()
    if len(mount_points) <= 0:
        mount_points = None
    return mount_points

# Return the filename defined here
def get_filename():
    return file

# Returns the number of mount points found
def get_mountpoint_cnt():
    mount_points = rs_plfs_config_query.get_mountpoints()
    return len(mount_points)

