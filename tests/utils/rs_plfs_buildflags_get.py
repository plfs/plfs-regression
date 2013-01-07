#!/usr/bin/env python
#
###################################################################################
# Copyright (c) 2009, Los Alamos National Security, LLC All rights reserved.
# Copyright 2009. Los Alamos National Security, LLC. This software was produced
# under U.S. Government contract DE-AC52-06NA25396 for Los Alamos National
# Laboratory (LANL), which is operated by Los Alamos National Security, LLC for
# the U.S. Department of Energy. The U.S. Government has rights to use,
# reproduce, and distribute this software.  NEITHER THE GOVERNMENT NOR LOS
# ALAMOS NATIONAL SECURITY, LLC MAKES ANY WARRANTY, EXPRESS OR IMPLIED, OR
# ASSUMES ANY LIABILITY FOR THE USE OF THIS SOFTWARE.  If software is
# modified to produce derivative works, such modified software should be
# clearly marked, so as not to confuse it with the version available from
# LANL.
# 
# Additionally, redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the following conditions are
# met:
# 
#    Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
#    Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 
#    Neither the name of Los Alamos National Security, LLC, Los Alamos National
# Laboratory, LANL, the U.S. Government, nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY LOS ALAMOS NATIONAL SECURITY, LLC AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL LOS ALAMOS NATIONAL SECURITY, LLC OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
# IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
# OF SUCH DAMAGE.
###################################################################################
#
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
