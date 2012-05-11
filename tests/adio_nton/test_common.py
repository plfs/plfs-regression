#!/usr/bin/env python
#
# Common variables and functions for this test

import os,re,sys,getpass

file = os.getenv("MY_MPI_HOST") +".adio_nton.out"

# Get the username to inject into the output target's filename
user = getpass.getuser()

# Figure out where the test is
curr_dir = os.getcwd()
basedir = re.sub('tests/adio_nton.*', '', curr_dir)

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
nprocs = 4 * int(ppn)

# Import the module with functions for finding mount points.
import rs_plfs_config_query
import rs_exprmgmtrc_target_path_append as tpa

def get_target_paths():
    mount_path = []
    mount_points = rs_plfs_config_query.get_mountpoints()
    if len(mount_points) > 0:
        for mnt in mount_points:
            top_dir = tpa.append_path([mnt])[0]
            target = str(top_dir) + "/" + str(file)
            mount_path.append(target)
    else:
        mount_path = None
    return mount_path

# Returns the number of mount points found
def get_mountpoint_cnt():
    mount_points = rs_plfs_config_query.get_mountpoints()
    return len(mount_points)

