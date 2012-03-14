#!/usr/bin/env python
#
# Common variables and functions for this test

import os,re,sys,getpass

file = os.getenv("MY_MPI_HOST") +".adio_nto1_strided.out"

# Get the username to inject into the output target's filename
user = getpass.getuser()

# Figure out where the test is
curr_dir = os.getcwd()
basedir = re.sub('tests/adio_nto1_strided.*', '', curr_dir)

# Add the directory that contains helper modules
utils_dir = basedir + "tests/utils"
if utils_dir not in sys.path:
    sys.path += [ utils_dir ]

# Import the needed common modules
import rs_exprmgmt_paths_add as em_p
# Add the experiment_management locations to sys.path
em_p.add_exprmgmt_paths(basedir)

# Import expr_mgmt so that we can make sure we get enough processes. We want
# enough to cover at least two nodes.
import expr_mgmt
ppn = expr_mgmt.config_option_value("ppn")
nprocs = 2 * int(ppn)

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

