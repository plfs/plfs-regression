#!/usr/bin/env python
#
# This script is to return the build flags that are necessary for linking
# against PLFS

import os,sys,re

# figure out where this script is.
script_dir = os.path.dirname( os.path.realpath( __file__ ) )
script_name = os.path.basename(__file__)

def check_script_location():
    """Make sure this script is in the proper place in the regression suite.

    Return values:
    - 0: the script is in the proper location
    - 1: the script is not in the proper location
    """
    if "/tests/utils" not in script_dir:
        print ("Error: " + str(script_name) + " is not located in the proper "
            + "place in the regression suite directory structure.")
        return 1
    else:
        return 0

def get_rs_plfs_buildflags(reg_dir):
    """Construct strings for the build flags that are necessary for building
    against PLFS.

    Input:
    - reg_dir: base directory of the regression suite

    Returns:
    - a 2-member list of the build flags to use. The first item in the list
      is the compile flags (CFLAGS). The second item in the list is the
      linking flags (LDFLAGS)
    """
    rs_plfs_lib_dir = (str(reg_dir) + "/inst/plfs/lib")
    rs_plfs_inc_dir = (str(reg_dir) + "/inst/plfs/include")
    
    rs_plfs_ldflags = ("-L" + str(rs_plfs_lib_dir) + " -Wl,-rpath="
        + str(rs_plfs_lib_dir) + " -Wl,--whole-archive -lplfs "
        + "-Wl,--no-whole-archive")
    rs_plfs_cflags = ("-I" + str(rs_plfs_inc_dir) + " -DHAS_PLFS")
    return [rs_plfs_cflags, rs_plfs_ldflags]


def main():
    """Main function for finding the build flags necessary for building
    against PLFS.

    Returns:
    - a 2-member list if the build flags were found successfully. The contents
      correspond to the return contents of get_rs_plfs_buildflags.
    - an empty list if there was an issue getting the flags
    """
    if check_script_location() != 0:
        return []
    # figure out the directory that the regression suite is based in
    reg_dir = re.sub('/tests/utils', '', script_dir)
    buildflags = get_rs_plfs_buildflags(reg_dir)
    if buildflags == []:
        return []
    else:
        return buildflags

# If this script is being called from the shell, we need to just print out the
# build flags.
if __name__ == "__main__":
    buildflags = main()
    if buildflags == []:
        sys.exit(1)
    else:
        print buildflags[0]
        print buildflags[1]
        sys.exit(0)
