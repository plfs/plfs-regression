#!/bin/bash
source /users/atorrez/Testing/regression//tests/utils/rs_env_init.sh
echo "Running /users/atorrez/Testing/regression//tests/utils/rs_plfs_fuse_mount.sh /var/tmp/plfs2.atorrez"
need_to_umount="True"
/users/atorrez/Testing/regression//tests/utils/rs_plfs_fuse_mount.sh /var/tmp/plfs2.atorrez
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
/users/atorrez/Testing/regression/tests/utils/rs_scratch_mount_find.sh

mpirun -n 16 /users/atorrez/Testing/regression/inst/test_fs/fs_test.yellowrail.x -target /scratch3/atorrez/yellowrail.cp_plfs_read.out -strided 1 -nodb -shift -nobj 1024 -touch 3 -op write -type 2 -check 3 -size 1024

# 1 jobs dispatched by list.
ret=$?
if [ "$ret" == 0 ]; then
    echo "Write successful"
else
    echo "Something wrong with writing."
    if [ "$need_to_umount" == "True" ]; then
        echo "Running /users/atorrez/Testing/regression//tests/utils/rs_plfs_fuse_umount.sh /var/tmp/plfs2.atorrez"
        /users/atorrez/Testing/regression//tests/utils/rs_plfs_fuse_umount.sh /var/tmp/plfs2.atorrez
    fi
    exit 1
fi
 echo "Copying file from non-plfs to plfs space"
cp /scratch3/atorrez/yellowrail.cp_plfs_read.out /var/tmp/plfs2.atorrez/atorrez/yellowrail.cp_plfs_read.out
mpirun -n 16 /users/atorrez/Testing/regression/inst/test_fs/fs_test.yellowrail.x -target plfs:/var/tmp/plfs2.atorrez/atorrez/yellowrail.cp_plfs_read.out -strided 1 -nodb -shift -deletefile -nobj 1024 -touch 3 -op read -type 2 -check 3 -size 1024

# 1 jobs dispatched by list.
if [ -e /scratch3/atorrez/yellowrail.cp_plfs_read.out ]; then rm /scratch3/atorrez/yellowrail.cp_plfs_read.out; fi
if [ -e /var/tmp/plfs2.atorrez/atorrez/yellowrail.cp_plfs_read.out ]; then rm /var/tmp/plfs2.atorrez/atorrez/yellowrail.cp_plfs_read.out; fi
if [ "$need_to_umount" == "True" ]; then
    echo "Running /users/atorrez/Testing/regression//tests/utils/rs_plfs_fuse_umount.sh /var/tmp/plfs2.atorrez"
    /users/atorrez/Testing/regression//tests/utils/rs_plfs_fuse_umount.sh /var/tmp/plfs2.atorrez
fi
