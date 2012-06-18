#!/bin/bash
source /users/atorrez/iotests/regression//tests/utils/rs_env_init.sh
for mnt in /var/tmp/plfs.atorrez /var/tmp/plfs.atorrez1
do
    echo "Running /users/atorrez/iotests/regression//tests/utils/rs_plfs_fuse_mount.sh $mnt"
    need_to_umount="True"
    /users/atorrez/iotests/regression//tests/utils/rs_plfs_fuse_mount.sh $mnt
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
    top=`/users/atorrez/iotests/regression//tests/utils/rs_exprmgmtrc_target_path_append.py $mnt`
    path=$top/rrz.non_adio_nto1_overwrite
    echo Using $path as target
    echo "Attempting to write to non-plfs space"
    for io_type in posix plfs
    do
        for size in 4194304 2097152 5242880
        do
            mpirun -n 16 /users/atorrez/iotests/regression/inst/test_fs/fs_test.rrz.x -io $io_type -target $path -strided 1 -nobj 1 -nodb -touch 3 -shift -type 2 -check 3 -size $size

# 1 jobs dispatched by list.

            let "file_size=16*size*1"
            target_file_size=`ls -al $path | awk '{print $5}'`
            if [ "$file_size" != "$target_file_size" ]; then
                echo "Error:  target file size does not match expected file size"
            else
                echo "Target file matches expected file size"
            fi
            if [ -e $path ]; then
                rm -f $path
            fi
        done
    done
    if [ "$need_to_umount" == "True" ]; then
        echo "Running /users/atorrez/iotests/regression//tests/utils/rs_plfs_fuse_umount.sh $mnt"
        /users/atorrez/iotests/regression//tests/utils/rs_plfs_fuse_umount.sh $mnt
    fi
done
