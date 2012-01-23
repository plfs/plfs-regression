#!/usr/bin/env python

import os,shlex,sys,subprocess,re,time,shutil,pickle,imp
from optparse import OptionParser,OptionGroup

# Parse command line arguments
def parse_args(num_required, num_test_types):
    """Parse the command line arguments.

    Requires two input parameters: the number of required command line
    arguments and the number of test types that are possible to run. The
    test types passed in the command line option will be used to figure out
    which tests in the control file to run.
    """

    usage = "Usage: %prog [options]"
    description = ("This script will submit tests within the tests directory.")
    parser = OptionParser(usage=usage, description=description)
    parser.set_defaults(types="1,2", basedir=".", control_file=None, 
        sub_id_file=None, dict_file=None, lockfile=None)
    group = OptionGroup(parser, "Required")
    group.add_option("-c", "--control", dest="control_file", help="Specify "
                      "which file to use in the tests directory to obtain a "
                      "list of tests to run. Each line should have a number "
                      "to specify the test's type and then a test name that "
                      "corresponds to a directory in the tests directory "
                      "which contains the test.", metavar="FILE")
    group.add_option("-i", "--idfile", dest="sub_id_file", help="Specify "
                      "the file to save job ids to. This file can be used "
                      "to check the status of running jobs.", metavar="FILE")
    group.add_option("-d", "--dictfile", dest="dict_file", help="Specify "
                      "the file to save the python dictionary that keeps "
                      "track of submitted tests. This file can be used "
                      "to supply a list of tests submitted by this script. "
                      "For instance, that list could be used to generate a "
                      "list of tests that need their results checked.",
                      metavar="FILE")
    parser.add_option_group(group)
    group = OptionGroup(parser, "Optional")
    group.add_option("-t", "--types", dest="types", help="Specify which "
                      "types of tests to run. The types are 1 (underlying "
                      "filesystem only; no plfs used), 2 (use plfs mount "
                      "point that is mounted through fuse), 3 (use "
                      "ADIO/patched mpi), and 4 (use plfs API). LIST can be "
                      "a comma-separated list of any of these digits:1 or 1,2 "
                      "or 1,2,4. Default is %default.", metavar="LIST")
    group.add_option("-b", "--basedir", dest="basedir", help="Specify the base "
                      "regression directory to be DIR. Only necessary when "
                      "this script is run as part of a cron job.", 
                      metavar="DIR")
    parser.add_option_group(group)
    (options, args) = parser.parse_args()

    if len(args) < num_required:
        parser.error("Required argument not provided. Use -h or --help for help.")
    elif len(args) > num_required:
        parser.error("Unknown extra arguments: " + str(args[1:]) 
                + ". Use -h or --help for help.")

    if options.control_file == None:
        parser.error("Required -c or --control not specified. Use -h or "
                "--help for help.")
    if options.sub_id_file == None:
        parser.error("Required -i or --idfile not specified. Use -h or "
                "--help for help.")
    if options.dict_file == None:
        parser.error("Required -d or --dictfile not specified. Use -h or "
                "--help for help.")

    # Get the types of tests to run into a list.
    types = [int(x) for x in options.types.split(',')]

    # Keep track in a table what types of tests are to be run as well
    # as check the types
    types_table=[]
    for i in range(0,num_test_types+1):
        types_table.append(False)
    for i in types:
        if i < 1 or i > num_test_types:
            parser.error("Invalid test type " + str(i) 
                    + ". Use -h or --help for help.")
        types_table[i] = True

    return options, args, types_table

def submit_tests(options, types_table):
    """Run tests specified in the control file in the tests directory.
    
    Return values:
    Successfully submitted at least one job flag and dictionary of jobs submitted.
    1, {}          - Problem working with files related to submitting tests.
    1, {non-empty} - Problems with submitting tests. Not one test fully submitted.
    0, {non-empty} - At least one test successfully submitted.
    """

#    sys.path += [ reg_base_dir + '/src/experiment_management/', './' ]
#    try:
#        import run_expr
#    except ImportError:
#        print ("Error: Unable to import run_expr from experiment_management. "
#            "Exiting...")
#        return 1, {}

    test_info = {}

    # Test to make sure the id file exits. If it doesn't, let the user know
    # and create it. This allows this script to be run outside of the regression
    # scripts by itself.
    if os.path.isfile(options.sub_id_file):
        print ("Using " + str(options.sub_id_file) + " to store "
            + "submitted job ids.")
    else:
        print ("Id file " + str(options.sub_id_file) + " does not exist. "
            + "Creating it...")
        os.system("touch " + str(options.sub_id_file))

    print "Opening id file " + str(options.sub_id_file)
    try:
        f_sub = open(options.sub_id_file, 'a')
    except IOError:
        print ("Error opening submit id file " + str(test_dir)
            + "/" + str(options.sub_id_file) + ". Exiting...")
        return -1, {}
    print "Successfully opened " + str(options.sub_id_file)

    test_dir = reg_base_dir + "/tests"
    print "Entering " + str(test_dir)
    try:
        os.chdir(test_dir)
    except OSError:
        print "Error: " + str(test_dir) + " does not exist. Exiting..."
        return 1, {}

    # Open the control file (will have a list of tests to run and their types)
    print "Opening control file " + str(options.control_file)
    try:
        f_cont = open(options.control_file, 'r')
    except IOError:
        print ("Error opening control file " + str(test_dir) 
               + "/" + str(options.control_file) + ". Exiting...")
        return 1, {}
    print "Successfully opened " + str(options.control_file)

    line_num = 0 # Keep track of the line we're on in the control file
    ids = [] # Keep track of the id of the last job submitted
    loaded = False # Keep track if import or reload statement is needed.
    last_id = -1 # Keep track of the last job successfully submitted.
    # Flag when at least one test reports successfully submitted. This will
    # be the return value: 0 for at least one submitted, 1 for none submitted.
    succ_submitted = 1

    for line in f_cont:
        # Parse the control file line by line, looking for valid lines
        # (lines with 2 non-commented fields). Use tokens to split up the line
        line_num += 1
        tokens = shlex.split(line,comments=True)
        if tokens == []: # Empty line or a line with only comments in it.
            continue
        if len(tokens) != 2:
            print ("Error in " + str(options.control_file) + " line " + str(line_num) 
                   + ". Improper number of fields. Skipping...")
            continue

        test_type = tokens[0]
        # Check the test type
        if (int(test_type)) < 0 or (int(test_type) > (len(types_table) - 1)):
            print ("Error in " + str(options.control_file) + " line " + str(line_num) 
                    + ". Improper test type " + str(test_type) 
                    + ". Skipping...")
            continue
        # Get the test's directory name (its location)
        test_loc = tokens[1]

        # We now have where to run the test and its valid test type
        if types_table[int(test_type)] == True:
            try:
                os.chdir(test_loc)
            except OSError:
                print ("Error in " + str(options.control_file) + " line " + str(line_num)
                       + ". No such directory " + str(test_loc)
                       + ". Skipping...")
                continue
            # Print out a delimiter to make parsing the output easier
            print "-" * 50
            print "Submitting test in directory " + str(test_loc)
            # Load test.py
            (fp, path, desc) = imp.find_module('reg_test', ['./'])
            reg_test = imp.load_module('reg_test', fp, path, desc)
            fp.close()
            ids = reg_test.main()
            # Check to see if the test was successfully submitted.
            if ids == [] or ids == None:
                print ("Error: there was a problem getting the last job id "
                    "from the test; nothing was returned by reg_test.py. "
                    "Unable to keep track of this test.")
                test_info[test_loc] = ['Unable to submit',
                    'Test passed nothing back when submitted.']
            # See if any submittals failed.
            if -1 in ids or "-1" in ids:
                print "Error: Unable to fully submit test " + str(test_loc)
                test_info[test_loc] = ['Unable to submit', '']
                for i in range(ids.count("-1")):
                    ids.remove("-1")
                for i in range(ids.count(-1)):
                    ids.remove(-1)
                if len(ids) > 0:
                    print ("Job ids associated with this test (the regression "
                        "suite will not wait for these to finish to check results):")
                    for i in ids:
                        print i
            else:
                succ_submitted = 0
                print ("Submitted test in directory " + str(test_loc))
                if (len(ids) == 1) and (ids[0] == 0 or ids[0] == "0"):
                    # Don't have to wait for this test to finish
                    print ("This test does not require the regression suite to "
                        "wait for it.")
                else:
                    print ("Job ids associated with this test:")
                    for i in ids:
                        print (i)
                        f_sub.write(str(i) + "\n")
                    last_id = ids[-1]
                test_info[test_loc] = ['Submitted', '']

            ids = []

            # Go back to the tests directory and do the next test.
            print "Entering " + str(test_dir)
            os.chdir(test_dir)
    print "-" * 50
    f_cont.close()
    f_sub.close()
    print "Entering " + str(reg_base_dir)
    sys.path.remove('./')
    os.chdir(reg_base_dir)
    return succ_submitted, test_info


# Main routine
def main():
    """The main routine for submitting tests inside the regression suite.

    Return values:
    0: At least some jobs submitted
    1: No jobs submitted.
    """

    required_args = 0
    num_test_types = 4
    options, args, types_table = parse_args(required_args, num_test_types)
    global reg_base_dir
    if options.basedir == ".":
        reg_base_dir = os.getcwd()
    else:
        reg_base_dir = options.basedir

    # Submit tests, getting a flag about whether or not at least one test was
    # successfully submitted  and a dictionary of jobs that need to be checked
    # and reported on.
    succ_sub, test_info = submit_tests(options=options, types_table=types_table)
#    succ_sub = 0
#    test_info = {"write_read_no_error": ['Submitted', ''], 
#                 "write_read_error": ['Submitted', '']}
    if succ_sub != 0:
        print ("Error: problems with submitting tests. No tests fully "
            "submitted.")
        return 1

    # Write out the test_info dictionary to be used later.
    print ("Writing dictionary containing what tests were submitted to "
        + str(options.dict_file) + ".")
    try:
        f = open(options.dict_file, 'w')
        pickle.dump(test_info, f)
        f.close()
    except IOError, detail:
        print ("Error writing dictionary file " + str(options.dict_file)
            + ": " + str(detail) + ".\nExiting without writing.")
        return 1
    print ("Successfully wrote dictionary to " + str(options.dict_file) + ".")
    return 0


if __name__ == "__main__":
    sys.exit(main())
