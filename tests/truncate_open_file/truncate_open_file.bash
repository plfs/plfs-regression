#!/usr/bin/env bash
#
# This script will write two files and compare their contents.
#
# Input:
# - two filenames: the two files that will be written. Their contents will be
#   compared against each other.
# Output:
# - 0 if the two files have identical contents after writing
# - 1 if the two files do not have identical contents after writing.

# Function to write to two files to compare their contents
#
# Input: 
# - two files to write to
# - number of times to put 'aaa a' into the file (each aaa and a will be
#   put on a separate line)
# Output:
# - 0 if the files match after writing
# - 1 if the files don't match
function write_files {
    file1=$1
    file2=$2
    num_string_sets=$3
    string=""
    for i in `seq 1 $num_string_sets`; do
        string=`echo $string "aaa" "a"`
    done
    # Create both files
    for file in $file1 $file2; do
        for str in $string ; do
            echo "echo-ing $str into $file"
            echo $str > $file
        done
    done

    # Check that the contents of the files match
    echo "Checking that $file1 and $file2 are the same using diff..."
    diff -q $file1 $file2
    ret=$?
    if [ $ret == 0 ]; then
        echo "SUCCESS: The files are the same"
        return_val=0
    else
        echo "ERROR: The files are not the same"
        return_val=1
    fi

    # Remove the files
    echo "Removing files..."
    rm -rf $file1 $file2
    if [ $? != 0 ]; then
        echo "Warning: unable to remove $file1 and/or $file2"
    fi

    return $return_val
}

# Check the number of command line parameters
if [ $# != 2 ]; then
    echo "Usage:"
    echo "$0 file1 file2"
    exit 1
fi

# Grab the files to work with from the command line
file1=$1
file2=$2

#plfs_version
echo "Using $file1 and $file2"

echo "First test"
write_files $file1 $file2 1
ret=$?
if [ $ret == 0 ]; then
    return_val=0
else
    return_val=1
fi

if [ "$ret" == 0 ]; then
# more aggressive test. Tests race condition
    echo "Second test"
    write_files $file1 $file2 2
    ret=$?
    if [ $ret == 0 ]; then
        return_val=0
    else
        return_val=1
    fi
fi

# Exit
exit $return_val
