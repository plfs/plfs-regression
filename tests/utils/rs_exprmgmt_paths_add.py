#!/usr/bin/env python
#
# Add the paths to experiment_managment to sys.path

import os,sys,re

def add_exprmgmt_paths(basedir):
    """Adds paths to experiment_management modules to sys.path

    Input:
    basedir: The regression suite's base directory.
    """
    expr_mgmt_dir = get_expr_mgmt_dir(basedir)
    expr_mgmt_lib = expr_mgmt_dir + '/lib'
    if expr_mgmt_lib not in sys.path:
        sys.path += [ expr_mgmt_lib ]
    if expr_mgmt_dir not in sys.path:
        sys.path += [ expr_mgmt_dir ]

def get_expr_mgmt_dir(dir):
    """Get a string of where the experiment_management directory is located.

    Input:
    dir: The regression suite's base directory
    """
    return dir + '/inst/experiment_management'
