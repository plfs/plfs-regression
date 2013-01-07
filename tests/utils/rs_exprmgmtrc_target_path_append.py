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
# This program is to append an optional experiment_managment parameter to all
# paths passed to it.

import sys,os,re
from optparse import OptionParser

# This script is probably not invoked from the directory it resides in. Figure
# out where this script is located because the experiment_managment helper
# scripts should be in the same directory.

# Get the current working directory
save_dir = os.getcwd()
# Get the directory of the script. This could be a relative path.
script_dir = os.path.dirname(__file__)
# Change directory to that directory
os.chdir(script_dir)
# Get the current working directory again. This is what is needed.
ab_script_dir = os.getcwd()
# Go back to the original directory
os.chdir(save_dir)

# Add ab_script_dir to the path if needed
if ab_script_dir not in sys.path:
        sys.path += [ ab_script_dir]

# Figure out the regression suite's base directory from ab_script_dir
basedir = re.sub('tests/utils.*', '', ab_script_dir)

# Import the module for dealing with experiment_managment paths
import rs_exprmgmt_paths_add as emp
# Add the experiment_management location to sys.path
emp.add_exprmgmt_paths(basedir)
import expr_mgmt

def append_path(paths):
    """Append experiment_management's rs_mnt_append_path to all elements of paths.

    Input:
        paths: a list of paths to append to
    Output:
        A copy of paths that has rs_mnt_append_path appended to each element.
        If rs_mnt_append_path is not defined in experiment_management's rc
        file, a copy of paths is returned.
    """
    # Get the optional path from experiment_management
    append_path = expr_mgmt.config_option_value("rs_mnt_append_path")
    ret_list = []
    for path in paths:
        if append_path != None:
            if path[-1] != "/":
                path += "/"
            ret_list += [str(path) + str(append_path)]
        else:
            ret_list += [path]
    return ret_list

def parse_args(argv):
    """Parse command line arguments. A mechanism for printing usage
    information.
    """
    usage = "\n $prog [PATH1 PATH2 ...]"
    description = ("This script appends experiment_managment's "
        + "rs_mnt_append_path parameter to each PATH given on the commmand "
        + "line. If rs_mnt_append_path is not specified in "
        + "experiment_managment's configuration, nothing is appended.")
    parser = OptionParser(usage=usage, description=description)
    options, args = parser.parse_args(argv)
    return args

if __name__ == "__main__":
    args = parse_args(sys.argv[1:])
    ret_list = append_path(args)
    print ' '.join(ret_list)
    sys.exit()
