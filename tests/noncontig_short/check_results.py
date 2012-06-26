#!/usr/bin/env python

import os,re,sys
from optparse import OptionParser
curr_dir = os.getcwd()
basedir = re.sub('tests/noncontig_short.*', '', curr_dir)

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

    #
    # Now check to see if there were any errors.
    #
    bad = "error" + "|" + "Failure"
    ok1 = "^#"
    ok2 = "No Errors"
    ok = str(ok1) + "|" + str(ok2)
    st2 = os.system('cat ' + str(output_file) + ' | egrep -v "'
            + str(ok) + '" | egrep -qi "' + str(bad) + '"')
    if st2 == 0:
        return ["FAILED", output_file, "Errors in output"]
    else:
        return ["PASSED"]

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
