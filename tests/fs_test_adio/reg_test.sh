#!/bin/bash
source /users/atorrez/iotests/regression//tests/utils/rs_env_init.sh
echo PATH=$PATH
echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH
mpirun -n 16 /users/atorrez/iotests/regression/inst/test_fs/fs_test.rrz.x -target plfs:/var/tmp/plfs.atorrez/atorrez/rrz.adio_write_read.out -strided 0 -nobj 4 -nodb -shift -type 2 -deletefile -size 1048760

# 1 jobs dispatched by list.
