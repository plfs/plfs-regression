#!/usr/bin/env python
#
# Submit the script just created.

# Figure out that base directory of the regression suite
import os,sys,re
curr_dir = os.getcwd()
basedir = re.sub('tests/adio_hints.*', '', curr_dir)

# Add the directory that contains helper modules
utils_dir = basedir + "tests/utils"
if utils_dir not in sys.path:
    sys.path += [ utils_dir ]

# Get the experiment_management paths added to sys.path if needed
import rs_exprmgmt_paths_add as emp
emp.add_exprmgmt_paths(basedir)

import expr_mgmt

# Script that we want experiment_managment to run.
script="reg_test.sh"

# Don't use mpirun; the field needs to be empty. Same with mpi_options.
mpirun=''

mpi_options = {}

mpi_program = ( curr_dir + "/" + str(script))

program_options = {}

def get_commands(expr_mgmt_options):
  global mpi_options, mpi_program, program_options 
  return expr_mgmt.get_commands( mpi_options=mpi_options, 
          mpi_program=mpi_program, program_options=program_options,
          mpirun=mpirun, expr_mgmt_options=expr_mgmt_options )
