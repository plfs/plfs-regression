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

import os,re,sys,imp
curr_dir = os.getcwd()
basedir = re.sub('tests/adio_nton.*', '', curr_dir)

# Add the directory that contains helper modules
utils_dir = basedir + "/tests/utils"
if utils_dir not in sys.path:
    sys.path += [ utils_dir ]
import rs_general_logfile_find as lgf

# Import the module for experiment_managment paths
import rs_exprmgmt_paths_add as emp
# Add the experiment_management locations to sys.path
emp.add_exprmgmt_paths(basedir)
import expr_mgmt

from optparse import OptionParser

import commands
from decimal import Decimal
# Load the common.py module to get common variables
(fp, path, desc) = imp.find_module('test_common', [os.getcwd()])
tc = imp.load_module('test_common', fp, path, desc)
fp.close()



num_outfiles_req = 1

def check(output_files):
    """Check out put files for this test.

    This function should be the only portion that needs to be edited
    for a specific test. It will receive a list of logfiles that
    should be in the order that the experiments were submitted in.
    In other words, output_files[0] is the output associated with
    the first job submitted through experiment_management,
    output_files[1] is the second, and so on.

    This function should return a list. The number of required fields depends:
    - if the test passed, it should pass a list where the first element
      is a string containing the single word PASSED.
    - if the test failed, it should pass a list where the first element
      is a string containing the single word FAILED. The second field should
      be a string containing a path to the logfile where the error condition
      occured. It is permissable to have the second field be an empty string
      by using '' if there is no specific log file to return.
    More output can be sent via using fields in the list after the required
    fields. For example, to send a description of what went wrong, return
    something like the following:

    return ['FAILED', '/path/to/some/log/file', 
        'Expected read error not seen']
    return ['PASSED', 'Took longer than usual, but ok']
    return ['FAILED', '', 'Job never started', 
        'something really bad happended']

    More than one field can be passed. Expect that each extra field will be
    printed on it's own line. Extra fields can be passed for PASSED of FAILED.
    """

    # Check that the run completed
    # Determine how many runs completed in this test and compare against
    # the number of mount points 
    print "Checking " + str(output_files[0])
    complete_cnt = commands.getoutput('grep "Completed IO Read." ' + str(output_files[0]) + ' | wc -l')
    complete_cnt = Decimal(complete_cnt)
    mount_count=tc.get_mountpoint_cnt()
    if complete_cnt != mount_count:
        return ["FAILED", output_files[0], "Test did not finish IO Read"]
    else:
        # Now check to see if there were any errors.
        bad = "error"
        ok1 = "^#|^MPICH_ABORT_ON_ERROR="
        ok2 = "Errors and warnings written to \(-errout\): stderr"
        ok3 = "MPICH_ABORT_ON_ERROR"
        ok = str(ok1) + "|" + str(ok2) + "|" + str(ok3)
        #status = os.system('cat ' + str(file) + ' | sed -e ' + str(fix) 
        #        + ' | egrep -v ' + str(ok) + ' | egrep -i ' + str(bad))
        st2 = os.system('cat ' + str(output_files[0]) + ' | egrep -v "' 
                + str(ok) + '" | egrep -qi ' + str(bad))
        if st2 == 0:
            return ["FAILED", output_files[0], "Errors in output"]
        else:
            return ["PASSED"]
    
def parse_args(argv):
    """Parse args."""

    # Find out if a specific output file was given on the command line
    usage = "Usage: %prog [options]"
    description = "This script will check the results of a regression test."
    parser = OptionParser(usage=usage, description=description)
    parser.set_defaults(file=None)
    parser.add_option("-f", "--files", dest="files", help="Specify what files "
                  "to check. May be a comma-separated list of files.",
                  metavar="FILE")
    (options, args) = parser.parse_args(argv[1:])

    if len(args) > 0:
        parser.error("Unknown extra arguments: " + str(args[:]) 
                     + ". Use -h or --help for help.")
    if options.files != None:
        num_outfiles_given = len(options.files.split(','))
        if num_outfiles_given != num_outfiles_req:
            parser.error("Wrong number of output files given "
                    "by --files option for this test. " + str(num_outfiles_req)
                    + " required; " + str(num_outfiles_given) + " given.")
    return options, args

def find_outfiles(options):
    """Determine output file absolute locations and return them in a list."""

    # If files were not given, find the youngest output files for today's date.
    if options.files == None:
        outfiles = lgf.find_newest(curr_dir + "/" + expr_mgmt.config_option_value("outdir"))
    else:
        # should only get one file thanks to the check in parse_args
        outfiles = lgf.find_given(options.files.split(','))
    return outfiles

# Main routine
def main(argv=None):
    """The main routine for checking the results of a test.

    Main must return a list, and it must make sure the check function
    returns values according to the requirements listed in the check
    function's description. Hence, main will check to make sure that when
    FAILED is returned, at list of at least two non-empty fields will 
    be returned.
    """

    if argv == None:
        argv = sys.argv
    options, args = parse_args(argv)
    logfiles = find_outfiles(options)
    if logfiles == []:
        return ['FAILED', '', 'No log files found to check']
    results = check(logfiles)
    if results[0] == "FAILED":
        if len(results) < 2:
            print ("Checkresults ERROR: insufficient number of fields passed back "
                "by check function. Neither log file nor reason for failure given.")
            results.extend(['', 'No reason given by check function for failure',
                'Please check and update test files in', str(curr_dir)])
        if len(results) == 2 and results[1] == '':
            print ("Checkresults ERROR: Empty log file field passed back by check "
                "function and no reason passed in optional field.")
            results.extend(['No reason given by check function for failure',
                'Please check and update test files in ', str(curr_dir)])
    return results

if __name__ == "__main__":
    status = main()
    if status[0] == "PASSED":
        print str(status[0])
        if len(status) > 1:
            print "Additional information provided by check function:"
            for s in status[1:]:
                print str(s)
    elif status[0] == "FAILED":
        print str(status[0])
        if len(status) < 2 or (len(status) >= 2 and status[1] == ''):
            pass
        else:
            print "Please see log file " + str(status[1])
        if len(status) > 2:
            print "Additional information provided by check function:"
            for s in status[2:]:
                print str(s)
    else:
        print "Checkresults ERROR: Unknown status returned by check function:"
        for s in status:
            print str(s)
