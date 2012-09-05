#!/usr/bin/env python
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
        os.environ["LD_LIBRARY_PATH"] = (mpi_inst_lib + ":" +
            os.environ["LD_LIBRARY_PATH"])

