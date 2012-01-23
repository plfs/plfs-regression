#!/bin/bash
source /users/atorrez/Testing/Regression//tests/utils/rs_env_init.sh
echo "Running /users/atorrez/Testing/Regression//tests/utils/rs_plfs_fuse_mount.sh /var/tmp/plfs2.atorrez"
need_to_umount="True"
/users/atorrez/Testing/Regression//tests/utils/rs_plfs_fuse_mount.sh /var/tmp/plfs2.atorrez
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
mpirun -n 16 /users/atorrez/Testing/Regression/inst/test_fs/fs_test.yellowrail.x -target /var/tmp/plfs2.atorrez/atorrez/yellowrail.write_read_no_error.out -strided 1 -nodb -shift -io posix -nobj 4 -hints panfs_concurrent_write=1 -type 2 -deletefile -size 1048760

# 1 jobs dispatched by list.
if [ "$need_to_umount" == "True" ]; then
    echo "Running /users/atorrez/Testing/Regression//tests/utils/rs_plfs_fuse_umount.sh /var/tmp/plfs2.atorrez"
    /users/atorrez/Testing/Regression//tests/utils/rs_plfs_fuse_umount.sh /var/tmp/plfs2.atorrez
fi
