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
# Set up a python environment to use plfs (does not affect the running
# python instance, but does affect calls to os.system, Popen, etc.)

import sys,os

def add_plfs_paths(dir=None):
    print "rs_env_init.py: Using " + str(dir) + " as base directory for regression suite."

    # Append the regression suite's plfs install directories to PATH
    # PLFS bin
    plfs_inst_bin = dir + "/inst/plfs/bin"
    try:
        if plfs_inst_bin not in os.environ["PATH"]:
            os.environ["PATH"] = plfs_inst_bin + ":" + os.environ["PATH"]
    except KeyError:
        # PATH is not in the dictionary of env variables yet.
        os.environ["PATH"] = plfs_inst_bin

    # PLFS sbin
    plfs_inst_sbin = dir + "/inst/plfs/sbin"
    try:
        if plfs_inst_sbin not in os.environ["PATH"]:
            os.environ["PATH"] = plfs_inst_sbin + ":" + os.environ["PATH"]
    except KeyError:
        # PATH is not in the dictionary of env variables yet.
        os.environ["PATH"] = plfs_inst_sbin

    # MPI bin
    mpi_inst_bin = dir + "/inst/mpi/bin"
    if mpi_inst_bin not in os.environ["PATH"]:
        os.environ["PATH"] = mpi_inst_bin + ":" + os.environ["PATH"]

    # MPI lib
    mpi_inst_lib = dir + "/inst/mpi/lib"
    try:
        if mpi_inst_lib not in os.environ["LD_LIBRARY_PATH"]:
            os.environ["LD_LIBRARY_PATH"] = (mpi_inst_lib + ":" + 
                os.environ["LD_LIBRARY_PATH"])
    except KeyError:
        #LD_LIBRARYY_PATH is not in the dictionary of env variables yet.
        os.environ["LD_LIBRARY_PATH"] = (mpi_inst_lib)

