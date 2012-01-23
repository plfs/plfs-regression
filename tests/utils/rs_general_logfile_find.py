#!/usr/bin/env python
#
# Functions related to finding output files

import os,sys,time

def find_all(dir):
    """Find all output files recursively in directory dir
    """
    date_file_list = []
    for root, sub_folders, files in os.walk(dir):
        for file in files:
            stats = os.stat(os.path.join(root,file))
            last_mod_date = time.localtime(stats[8])
            date_file_tuple = last_mod_date, os.path.join(root,file)
            date_file_list.append(date_file_tuple)
    date_file_list.sort()
    date_file_list.reverse() # Newest now first
    file_list = []
    for file in date_file_list:
        file_list.append(file[1])
    return file_list

def find_newest(dir):
    """Find the newest output recursively in directory dir.

    This function returns a list with one element in it. This is to be
    consistent with the possible output of find_given which needs to have the
    ability to pass a list with more than one element.
    """
    file_list = find_all(dir)
    if file_list == []:
        result = []
    else:
        result = [ file_list[0] ]
    return result

def find_given(filelist):
    """Find files given in filelist and return full paths of those found
    """
    outfiles = []
    for file in filelist:
        if os.path.isfile(file) == False:
            print "ERROR: file " + str(file) + " does not exist."
            return []
        outfiles.append(os.path.join(os.getcwd(),file))
    return outfiles
