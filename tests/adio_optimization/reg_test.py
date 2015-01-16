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
# Run a plfs regression test.

import os,sys,re,imp,subprocess

# Load the common.py module to get common variables
(fp, path, desc) = imp.find_module('test_common', [os.getcwd()])
tc = imp.load_module('test_common', fp, path, desc)
fp.close()

import run_expr

def main(argv=None):
    """The main routine for submitting and running a test.

    Returns a list of job ids submitted for this test.
    """
    if argv == None:
        argv = sys.argv

    # Experiment_management script to run
    input = tc.curr_dir + "/input.py"
    # Generated script
    script = "reg_test.sh"
    # Script that can be passed to experiment_management that will run the
    # generated script
    input_script = "input_script.py"
    walltime = "10:00"

    # get all mountpoints and associated target paths and filename
    target_paths = tc.get_target_paths()
    if target_paths == None:
        print ("Error getting mountpoint")
        return [-1]

    # Create the script
    try:
        f = open(script, 'w')
        f.write('#!/bin/bash\n')
        # Set up the environment
        f.write('source ' + str(tc.basedir) + '/tests/utils/rs_env_init.sh\n')
        # Check environment variables to make sure we're using the right
        # binaries and libraries.
        f.write("echo PATH=$PATH\n")
        f.write("echo LD_LIBRARY_PATH=$LD_LIBRARY_PATH\n")
        # Convert list into space delimited targets 
        paths=' '.join(target_paths)
        # Create a for loop to iterate throuh all mountpoints/paths
        f.write('for path in ' + str(paths) + '\n')
        f.write('do\n')
        f.write('   echo Using $path as target\n')
        fs_test_command = str(tc.em_p.get_expr_mgmt_dir(tc.basedir)) + "/run_expr.py --dispatch=list " + str(input)

        cmd = subprocess.Popen([fs_test_command], stdout=subprocess.PIPE, shell=True)
        fs_test_run, errors = cmd.communicate()
        f.write("   " + str(fs_test_run) + '\n')
        f.write('done\n')

        f.close()
        os.chmod(script, 0764)
    except (IOError, OSError), detail:
        print ("Problem with creating script " + str(script) 
            + ": " + str(detail))
        return [-1]

    # Run the script
    last_id = run_expr.main(['run_expr', str(tc.curr_dir) + "/" + str(input_script),
        '--nprocs=' + str(tc.nprocs), '--walltime=' + str(walltime), 
        '--dispatch=msub'])

    return [0]

if __name__ == "__main__":
    # If reg_test.py is being called directly, make sure the regression suite's
    # PLFS and MPI are in the appropriate environment variables. This should
    # work because test_common was already loaded.
    import rs_env_init
    rs_env_init.add_plfs_paths(tc.basedir)

    result = main()
    if result[-1] > 0:
        sys.exit(0)
    else:
        sys.exit(1)
