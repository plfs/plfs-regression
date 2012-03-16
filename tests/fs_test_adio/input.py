#!/usr/bin/env python
#
# A simple read and write using adio

import os,sys,re,getpass
curr_dir = os.getcwd()
basedir = re.sub('tests/fs_test_adio.*', '', curr_dir)

# Add the directory that contains helper modules
utils_dir = basedir + "tests/utils"
if utils_dir not in sys.path:
    sys.path += [ utils_dir ]

# Get experiment_management paths added to sys.path if needed
import rs_exprmgmt_paths_add as emp
emp.add_exprmgmt_paths(basedir)

# Import fs_test
import fs_test
import expr_mgmt

# Import the module with functions for finding mount points and targets
import rs_plfs_config_query

# Get a target to use for this test.
file = os.getenv("MY_MPI_HOST") + ".fs_test_adio.out"
user = getpass.getuser()
mount_points = rs_plfs_config_query.get_mountpoints()
mount_point = mount_points[-1]
target = str(mount_point) + "/" + str(user) + "/" + str(file)

# Want enough processes to fill up two nodes
ppn = expr_mgmt.config_option_value("ppn")
np = 2 * int(ppn)

mpi_options = {
    "n"     : [ np ]
}

mpi_program = ( str(basedir) + "inst/test_fs/fs_test."            
            + os.getenv("MY_MPI_HOST") + ".x" )

program_options = {
  "size"       : [ "48M" ],
  "deletefile" : [ '' ],
  "shift"      : [ '' ],
  "time"      : [ 300 ],
  "nodb"       : [ ''],
  "nodb"       : [ ''],
  "noextra"       : [ ''],
  "sync"      : [ '' ],
  "barriers"   : [ 'aopen' ],
  "strided"  : [ 0 ],
  "target"   : [ "plfs:" + str(target) ]
}

# fs_test doesn't need program_arguments

def get_commands(expr_mgmt_options):
  global mpi_options, mpi_program, program_options 
  return fs_test.get_commands( mpi_options=mpi_options, 
          mpi_program=mpi_program, program_options=program_options,
          n1_strided=False, n1_segmented=False, nn=True, auto_cw=True,
          expr_mgmt_options=expr_mgmt_options )
