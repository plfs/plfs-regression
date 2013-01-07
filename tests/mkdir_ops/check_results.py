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

import os,re,sys
from optparse import OptionParser
curr_dir = os.getcwd()
basedir = re.sub('tests/mkdir_ops.*', '', curr_dir)

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

# Module to help find output files
import rs_general_logfile_find as lgf

num_outfiles_req = 1

def check(output_file):
    """Check a single output file
    """
    print "Checking " + str(output_file)

    st1 = os.system('egrep -q "PASSED" ' + str(output_file))
    if st1 == 0:
        #
        # I may have to change this to things that mkdir_ops.tcsh can put in the
        # output that indicated that there was a failure. In that case, the
        # "bad" word is "Failure".
        #
        # Now check to see if there were any errors.
        #
        bad = "error" + "|" + "Failure"
        ok1 = "^#"
        #ok = str(ok1) + "|" + str(ok2) + "|" + str(ok3)
        ok = str(ok1)
        st2 = os.system('cat ' + str(output_file) + ' | egrep -v "'
                + str(ok) + '" | egrep -qi "' + str(bad) + '"')
        if st2 == 0:
            return ["FAILED", output_file, "Errors in output"]
        else:
            return ["PASSED"]
    else:
        return ["FAILED", output_file, "Test did not successfully perform the mkdir operations"]

def parse_args(argv):

    # Find out if a specific output file was given on the command line
    usage = "Usage: %prog [options]"
    description = "This script will check the results of a regression suite test."
    parser = OptionParser(usage=usage, description=description)
    parser.set_defaults(files=None)
    parser.add_option("-f", "--files", dest="files", help="Specify what files "
                  "to check. May be a comma-separated list of files.",
                  metavar="FILE")
    (options, args) = parser.parse_args(argv[1:])

    if len(args) > 0:
        parser.error("Unknown extra arguments: " + str(args[:])
                     + ". Use -h or --help for help.")

    # Check the number of files to check given by --files
    if options.files != None:
        num_outfiles_given = len(options.files.split(','))
        if num_outfiles_given != num_outfiles_req:
            parser.error("Wrong number of output files given "
                "by --files option for this test. " + str(num_outfiles_req)
                + " required; " + str(num_outfiles_given) + " given.")
    return options, args

def find_outfiles(options):
    """Determine output file absolute locations and return them in a list."""
    if options.files == None:
        outfiles = lgf.find_newest(curr_dir + "/" + expr_mgmt.config_option_value("outdir"))
    else:
        outfiles = lgf.find_given(options.files.split(','))
    return outfiles

def main(argv=None):
    if argv == None:
        argv = sys.argv
    options, args = parse_args(argv)
    logfiles = find_outfiles(options)
    if logfiles == []:
        return ['FAILED', '', 'No log files found to check']
    results = check(logfiles[0])
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
