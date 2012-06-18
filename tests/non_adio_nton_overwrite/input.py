#!/usr/bin/env python
#
# A test where fs_test writes a file, a single character in the file is
# changed, and then fs_test reads it in. There should be exactly one
# error reported.

import imp,os
(fp, path, desc) = imp.find_module('test_common', [os.getcwd()])
test_common = imp.load_module('test_common', fp, path, desc)
fp.close()

import fs_test

mpi_options = {
    "n"     : [ test_common.nprocs ]
}

mpi_program = ( str(test_common.basedir) + "inst/test_fs/fs_test."            
            + os.getenv("MY_MPI_HOST") + ".x" )

program_options = {
  "size"       : [ '$size' ],
  "shift"      : [ '' ],
  "nodb"       : [ ''],
  "type"       : [ 2 ],
  "nobj"       : [ 1 ],
  "io"         : [ '$io_type' ],
#  "op"         : [ 'write' ],
  "touch"      : [ '3' ],
  "check"      : [ '3' ],
  "target"     : [ '$path' ]
#  "target"     : [ '$path' ]
}

# fs_test doesn't need program_arguments

def get_commands(expr_mgmt_options):
  global mpi_options, mpi_program, program_options 
  return fs_test.get_commands( mpi_options=mpi_options, 
          mpi_program=mpi_program, program_options=program_options,
          n1_strided=False, n1_segmented=False, nn=True,
          expr_mgmt_options=expr_mgmt_options )
