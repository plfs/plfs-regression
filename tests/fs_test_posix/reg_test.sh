#!/bin/bash
source /users/atorrez/iotests/regression//tests/utils/rs_env_init.sh
echo "Running /users/atorrez/iotests/regression//tests/utils/rs_plfs_fuse_mount.sh /var/tmp/plfs.atorrez"
need_to_umount="True"
/users/atorrez/iotests/regression//tests/utils/rs_plfs_fuse_mount.sh /var/tmp/plfs.atorrez
ret=$?
if [ "$ret" == 0 ]; then
    echo "Mounting successful"
    need_to_umount="True"
elif [ "$ret" == 1 ]; then
    echo "Mount points already mounted."
    need_to_umount="False"
else
    echo "Something wrong with mounting."
    exit 1
fi
mpirun -n 512 /users/atorrez/iotests/regression/inst/test_fs/fs_test.rrz.x -strided 0 -nodb -sync -io posix -target /var/tmp/plfs.atorrez/atorrez/rrz.fs_test_general_posix.%s.%r -noextra -shift -hints panfs_concurrent_write=0 -time 300 -barriers aopen -size 48M -type 1 -deletefile

# 1 jobs dispatched by list.
if [ "$need_to_umount" == "True" ]; then
    echo "Running /users/atorrez/iotests/regression//tests/utils/rs_plfs_fuse_umount.sh /var/tmp/plfs.atorrez"
    /users/atorrez/iotests/regression//tests/utils/rs_plfs_fuse_umount.sh /var/tmp/plfs.atorrez
fi
