#!/usr/bin/env python
#
# Common functions for this regression test

import os,sys,re,getpass

curr_dir = os.getcwd()
basedir = re.sub('tests/data-sieving.*', '', curr_dir)

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
nprocs = 4

# Need the runcommand from experiment_management
runcommand = expr_mgmt.config_option_value("runcommand")

# Import the module with functions for finding mount points.
import rs_plfs_config_query
import rs_exprmgmtrc_target_path_append as tpa

def get_mountpoint():
    mount_points = rs_plfs_config_query.get_mountpoints()
    if len(mount_points) > 0:
        mount_point = mount_points[-1]
    else:
        mount_point = None
    return mount_point

def get_target():
    mount_point = get_mountpoint()
    if mount_point != None:
        top_dir = tpa.append_path([mount_point])[0]
        target = str(top_dir) + "/" + str(file)
    else:
        target = None
    return target

# Return a list of mount_points
def get_mountpoints():
    mount_points = rs_plfs_config_query.get_mountpoints()
    if len(mount_points) <= 0:
        mount_points = None
    return mount_points

# Returns the number of mount points found
def get_mountpoint_cnt():
    mount_points = rs_plfs_config_query.get_mountpoints()
    return len(mount_points)
