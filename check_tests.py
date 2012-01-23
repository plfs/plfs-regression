#!/usr/bin/env python

import os,shlex,sys,subprocess,re,time,shutil,pickle,datetime
from optparse import OptionParser,OptionGroup

class unable_to_continue_error(Exception):
    """Error to throw when it is impossible to check tests based on input.
    
    Attributes:
        msg -- explanation of the error
    """

    def __init__(self, msg):
        self.msg = msg
    def __str__(self):
        return str(self.value)

# Parse command line arguments
def parse_args(num_required):
    """Parse the command line arguments.

    Requires one input parameter: the number of required command line
    arguments.
    """

    usage = "Usage: %prog [options]"
    description = ("This script will check tests that are running within the "
                   "tests directory.")
    parser = OptionParser(usage=usage, description=description)
    parser.set_defaults(sub_id_file=None, dict_file=None, email_addr=None,
        email_msg_include=None, logfile=None, basedir=".", nodelete=False,
        noemail=False, logfile_mode='w')
    group = OptionGroup(parser, "Required")
    group.add_option("-d", "--dictfile", dest="dict_file", help="Specify "
                      "the file that has the saved python dictionary that keeps "
                      "track of submitted tests. This file will be used to "
                      "generate a list of tests that need their results "
                      "checked.", metavar="FILE")
    parser.add_option_group(group)
    group = OptionGroup(parser, "Optional")
    group.add_option("-i", "--idfile", dest="sub_id_file", help="Specify "
                      "the file that has saved job ids. This file will be used "
                      "to check the status of running jobs. When all jobs are "
                      "finished, this program will remove this file. "
                      "If this option is not specified, this program will "
                      "assume that all jobs are done and will skip waiting. "
                      "It will go straight to checking results.", 
                      metavar="FILE")
    group.add_option("-e", "--emailaddr", dest="email_addr", help="Specify "
                      "the email address to send the generated email to. If "
                      "this option is not used, --noemail must be used.",
                      metavar="ADDR")
    group.add_option("-m", "--emailmsginc", dest="email_msg_include",
                      help="Specify files to include in the summary email. "
                      "A comma-separated list can be passed and each file "
                      "will be included in the same order as given in the "
                      "list. They will be included before results from this "
                      "script are printed out.", metavar="file[,file...]")
    group.add_option("-f", "--logfile", dest="logfile", help="Instead of "
                      "using standard out, specify an output file for "
                      "messages.", metavar="FILE")
    group.add_option("--logfile_mode", dest="logfile_mode", help="Specify "
                      "writing mode for file given by --logfile. Can be a for "
                      "append or w for write. Write will overwrite the file "
                      "specified by --logfile, append will just add to that "
                      "file. Default is w.", metavar="MODE")
    group.add_option("-b", "--basedir", dest="basedir", help="Specify the base "
                      "regression directory to be DIR. Only necessary when "
                      "this script is run as part of a cron job.", 
                      metavar="DIR")
    group.add_option("--nodelete", action="store_true", dest="nodelete", 
                      help="Tell the script to not delete the output of "
                      "tests that PASSED.")
    group.add_option("--noemail", action="store_true", dest="noemail",
                      help="Tell the script to not generate an email.")
    parser.add_option_group(group)
    (options, args) = parser.parse_args()

    if len(args) < num_required:
        parser.error("Required argument not provided. Use -h or --help for help.")
    elif len(args) > num_required:
        parser.error("Unknown extra arguments: " + str(args[1:]) 
                + ". Use -h or --help for help.")

    if options.dict_file == None:
        parser.error("Required -d or --dictfile no specified. Use -h or "
            "--help for help.")
    if options.email_addr == None and options.noemail == False:
        parser.error("-e,--emailaddr not used without specifying --noemail. "
            "Use -h or --help for help.")
    if options.logfile_mode != 'w' and options.logfile_mode != 'a':
        parser.error("Invalid option to --logfile_mode. Only w or a is "
            "permitted. Use -h or --help for help.")

    return options, args

def get_id_from_file(id_file):
    print ("Getting a job id from id file " + str(id_file))
    try:
        f = open(id_file, 'r')
        # if the file is empty, id will be '' after the following statement
        id = f.readline().strip()
        f.close()
    except IOError, detail:
        msg = ("Check_tests.py error in get_id_from_file: Problem getting id "
            "from id file " + str(id_file) + ": " + str(detail) + ".")
        print msg
        raise unable_to_continue_error(msg)
        id = -1
    if id == '':
        print ("No more ids in file " + str(id_file))
    else:
        print ("Got id " + str(id))
    return id
    
def wait_tests(id_file):
    """Wait for the jobs to complete that are listed in id_file.
    
    id_file should be a file with job ids in it to wait for
    return values:
    0: All jobs are finished
    1: Unable to wait for jobs for some reason.
    """

    id = get_id_from_file(id_file)

    while id != '':

        print (str(time.asctime()) + ": Waiting for job " 
            + str(id) + " to complete.")

        # Get the status of the job
        ps = subprocess.Popen(["checkjob " + str(id)
            + " | grep State | awk '{print $2}'"], stdin=None, 
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        ps_output = ps.communicate()

        # Check that we have a valid job id.
        if len(ps_output[1]) > 0:
            msg = ("Check_results.py error in wait_tests: Invalid job id " 
                + str(id) + " in id file " + str(id_file) + ".")
            print msg
            raise unable_to_continue_error(msg)

        # There should be only a single element in stdout
        state = ps_output[0].strip()
        if state == "Completed" or state == "Removed":
            # Remove the job id from the file
            os.system("sed -i '/" + str(id) + "/d' " + str(id_file))
            # Get another id from the file
            id = get_id_from_file(id_file)
                
            continue
        # If we're here, there is a job that isn't finished yet. Sleep for a bit.
        sys.stdout.flush()
        time.sleep(60)
    print "All jobs complete."
    return 0


class MyWriter:
    """Write out to a stdout and a file with one print command."""

    def __init__(self, stdout, filename):
        self.stdout = stdout
        try :
            self.logfile = open(filename, "a")
        except OSError:
            print ("Error: Unable to open file " + str(filename) + "to store "
                "stdout output. Stdout will not be logged.")
            self.logfile = None

    def write(self, text):
        self.stdout.write(text)
        if self.logfile != None:
            self.logfile.write(text)

    def close(self):
        if self.logfile != None:
            self.logfile.close()

    def flush(self):
        self.stdout.flush()
        if self.logfile != None:
            self.logfile.flush()


def checkresults(options, tests_status, email_file):
    """Loop over the jobs in tests_status and get the results. Output the results.
    
    Input:
    options contains the command line inputs. This is needed to find out if tests
    that pass should remove their output files.
    tests_status is a dictionary where the key is a test name/directory name for
    a test. The value is a list that should have the first element either
    "Unable to submit" or "Submitted" (call submit_tests first to have this
    dictionary).
    email_file is a file name that will be used to store a summary of pass/fail
    for each test. This file can be used to email results.

    Return values:
    0: all tests passed
    1: some tests passed, but not all
    2: tests directory does not exist, tests not checked.
    """

    sys.path += [ reg_base_dir + '/inst/experiment_management/lib' ]
    from expr_mgmt import config_option_value as em_config_option_value

    print "Now checking results of tests."
    # Add ./ to sys.path so that we can import each test's checkresults.py as
    # we enter each directory.
    sys.path += ['./']
    # Figure out where the tests directory is so that we can return to it
    test_dir = reg_base_dir + "/tests"
    print "Entering " + str(test_dir)
    try:
        os.chdir(test_dir)
    except OSError:
        print "Error: " + str(test_dir) + " does not exist. Exiting..."
        return 2

    # Variable to keep track if any tests fail.
    all_passed = True
    # Variable to keep track if import or reload statement is needed.
    loaded = False
    # Dictionaries for keeping track of what tests pass, fail, etc.
    tests_pass = {}
    tests_fail = {}
    tests_not_submitted = {}
    tests_other = {}
    # Loop through the keys in tests_status
    for key in tests_status.keys():
        # Skip tests that we were not able to submit.
        if tests_status[key][0] == "Unable to submit":
            tests_not_submitted[key] = tests_status[key]
            del tests_status[key]
            all_passed = False
            continue

        print "Entering " + str(test_dir) + "/" + str(key)
        os.chdir(key)

        # We need to load checkresult.py in each directory, but python doesn't
        # reparse a module once loaded, even if it is removed by del and then
        # re-imported. Python has to be forced to reparse the file by using
        # reload. Reload can only be used, however, after the module is loaded
        # using import. So, for the first key, we have to use import; for all 
        # subsequent keys, we have to reload.
        if loaded == False:
            import check_results
            loaded = True
        else:
            reload(check_results)
        # Pass arguments to check_results.main so that it doesn't use sys.argv
        # We should get a list back from check_results.main
        try:
            result = check_results.main(['check_results'])
        except Exception, e:
            print ("Unexpected python error was not caught in executing "
                + "check_results.main():\n"
                + str(sys.exc_info()[0]) + ", " + str(sys.exc_info()[1]))
            print ("Please correct the issue with the script.")
            result = ['FAILED', '', 'check_results.py raised an unexpected exception.']

        # Print test status and output based on result[0] (PASSED, FAILED, etc)
        if result[0] == "PASSED":
            tests_pass[key] = result
            print result[0]
            if len(result) > 1:
                print "Additional information provided by checkresults.py:"
                for s in result[1:]:
                    print str(s)
            if options.nodelete == False:
                # Remove the output directory only if the test passed.
                outdir = em_config_option_value("outdir")
                print ("Removing output directory " + str(outdir))
                try:
                    shutil.rmtree(outdir)
                except OSError:
                    print ("Error: unable to remove default output directory "
                        + str(outdir) + ".")
        elif result[0] == "FAILED":
            # The main method of checkresults should return a list of at least
            # two non-empty elements when result[0] == FAILED
            tests_fail[key] = result
            all_passed = False
            print str(result[0])
            if result[1] == '':
                pass
            else:
                print "Please see log file " + str(result[1])
            if len(result) > 2:
                print "Additional information provided by checkresults.py:"
                for s in result[2:]:
                    print str(s)
        else:
            print ("Warning: checkresults.py did not return PASSED or FAILED. "
                "Returned the following strings:")
            for s in result:
                print str(s)
            tests_other[key] = result
            all_passed = False
        del tests_status[key]

        # Flush the output
        sys.stdout.flush()

        print "Entering " + str(test_dir)
        os.chdir(test_dir)

    print "Done checking results of tests."
    print "Entering " + str(reg_base_dir)
    os.chdir(reg_base_dir)
    sys.stdout.flush()

    # Remove the last occurence of ./ from sys.path (should be the one we added).
    path_copy = sys.path
    path_copy.reverse()
    path_copy.remove('./')
    path_copy.reverse()
    sys.path = path_copy

    if all_passed == True:
        ret = 0
    else:
        ret = 1
    return (ret, tests_fail, tests_other, tests_not_submitted, tests_pass)

def print_summary(options, tests_fail, tests_other, tests_not_submitted, 
    tests_pass):
    """Print out a summary of the differenct classes of tests."""

    print "\n\nSummary of tests that were run"
    if options.logfile != None:
        print "Please also see " + str(options.logfile) + "."
    # Report failed jobs
    for k, v in tests_fail.iteritems():
        print str(k) + "..." + str(v[0])
        if v[1] == '':
            pass
        else:
            print "Please see log file " + str(v[1])
        if len(v) > 2:
            for s in v[2:]:
                print str(s)
    # Report unknown jobs
    for k, v in tests_other.iteritems():
        print str(k) + "...FAILED"
        print "Did not return PASSED or FAILED. Did return the following:"
        for s in v:
            print str(s)
    # Report jobs that weren't submitted
    for k, v in tests_not_submitted.iteritems():
        print str(k) + "..." + str(v[0])
    # Report jobs that passed
    for k, v in tests_pass.iteritems():
        print str(k) + "..." + str(v[0])
        if len(v) > 1:
            for s in v[1:]:
                print str(s)


def catastrophic_exit(options, msg, dir):
    """When we need to exit before removing the job id file
    
    Use this function to exit check_tests.py when it is not possible to get
    to a point that the job id file can be removed. Since this file is a lock
    file, but check_tests.py is unable to proceed to a point to remove it,
    user intervention is needed. This function will perform tasks to halt all
    future regression instances and notify the user.
    """

    msg = (str(msg) + "\nRegression in " + str(dir) + " is catastrophically "
        "exiting. We will atempt to create a DO_NOT_RUN_REGRESSION file so "
        "that future regression runs will not happen. We will then exit. "
        "Please remove this file if regressions are to continue after "
        "troubleshooting the issue outlined above. Please also see log "
        "files in " + str(dir) + ".")

    if options.logfile != None:
        msg = (str(msg) + "\nCheck_results.py has logged it's output into "
            + str(options.logfile) + ". Please also see that file.")

    try:
        f = open(str(dir) + '/DO_NOT_RUN_REGRESSION', 'w')
    except IOError:
        msg = (str(msg) + "\nUnable to create DO_NOT_RUN_REGRESSION file.")
    try:
        f.close()
    except:
        pass

    if options.noemail == False:
        subj = ("PLFS regression on " + str(os.getenv('HOSTNAME')) 
            + ": URGENT: user intervention required")
        os.system("echo \"" + str(msg) + "\" | /bin/mail -s \"" + str(subj) 
            + "\" " + str(options.email_addr))
    else:
        print str(msg)
    sys.exit(1)


# Main routine
def main():
    """The main routine for checking running tests inside the regression suite.

    Return values:
    0: All tests passed
    1: Some tests passed, but not all
    2: Problems with submitting jobs or job output such that results of tests
       were not checked
    """

    required_args = 0
    num_test_types = 4
    options, args = parse_args(required_args)
    global reg_base_dir
    if options.basedir == ".":
        reg_base_dir = os.getcwd()
    else:
        reg_base_dir = options.basedir

    try:
    # If this block doesn't complete, it is a catastrophic error condition because
    # it is unknown if check_tests.py can ever complete. There could be invalid
    # job ids in the id file or some of the files can't be opened or properly
    # removed.
        # Set up output method
        if options.logfile != None:
            try:
                f = open(options.logfile, options.logfile_mode)
            except IOError:
                msg = ("Check_tests.py Error: unable to open log file " + str(options.logfile)
                    + " for logging check_tests output.")
                print msg
                raise unable_to_continue_error(msg)
            old_stdout = sys.stdout
            old_stderr = sys.stderr
            sys.stdout = f
            sys.stderr = f
            print ("\nOpened log file " + str(options.logfile) + " for "
                "logging at "
                + str(datetime.datetime.isoformat(datetime.datetime.now())))

        # If we are to wait
        if options.sub_id_file != None:
            if os.path.isfile(options.sub_id_file):
                # Now wait for the job to complete
                status = wait_tests(id_file=options.sub_id_file)
            else:
                msg = ("Check_tests.py Error: id file "
                    + str(options.sub_id_file) + " doesn't "
                    "exist. Unable to properly check tests.")
                print msg
                raise unable_to_continue_error(msg)
    
#    test_info = {"write_read_no_error": ['Submitted', ''], "write_read_error": ['Submitted', '']}
        # Start checking results.
        # Read in the dictionary with the list of needed jobs.
        print ("Attempting to read in list of tests to check from file"
            + str(options.dict_file))
        try:
            ff = open(options.dict_file, 'r')
            test_info = pickle.load(ff)
            ff.close()
        except (IOError, pickle.UnpicklingError), detail:
            msg = ("Check_tests.py Error: Unable to read in python dictionary "
                "file " + str(options.dict_file) + ": " + str(detail) 
                + ".\nWe have no idea what tests to check.")
            print msg
            raise unable_to_continue_error(msg)

    except unable_to_continue_error, e:
        catastrophic_exit(options=options, msg=e.msg, dir=reg_base_dir)

    # If we get here, there was enough information to get through waiting for
    # tests and the proper files were created/removed. We can now check the
    # results of the tests.

    print ("Successfully loaded dictionary from dictionary file. Closing and "
        "removing dictionary file.")
    try:
        os.remove(options.dict_file)
    except OSError:
        print ("Check_results.py Warning: problem removing "
            + str(options.dict_file) + ". Continuing...")

    # File to put a summary in so that it can be easily emailed. Make sure the
    # file doesn't exist
    if options.noemail == False:
        email_file = '.email_summary.temp'
        if os.path.isfile(email_file):
            try:
                os.remove(email_file)
            except OSError:
                print ("Error: Unable to remove existing email summary file. "
                    "No email will be sent.")
                email_file = None
    else:
        email_file = None

    # Check each job in test_info and report on it
    (status, tests_fail, tests_other, tests_not_submitted, 
    tests_pass) = checkresults(options=options, tests_status=test_info, 
        email_file=email_file)

    if status == 0:
        r_status = "PASSED"
    else:
        r_status = "FAILED"

    # Print out a summary to stdout and a file for later emailing
    if email_file != None:
        saved_stdout = sys.stdout
        sys.stdout = MyWriter(sys.stdout, email_file)

    # Print out a summary
    print_summary(options=options, tests_fail=tests_fail,
        tests_other=tests_other, tests_not_submitted=tests_not_submitted,
        tests_pass=tests_pass)
    
    # Put the output back to normal so that only the summary is in the file
    if email_file != None:
        sys.stdout.close()
        sys.stdout = saved_stdout

        # Email the summary
        print "Preparing to send email message."
        list_string = ""
        if options.email_msg_include != None:
            include_list = options.email_msg_include.strip().split(',')
            for l in include_list:
                list_string = list_string + " " + str(l)
        os.system("cat" + str(list_string) + " " + str(email_file)
            + " | /bin/mail -s \"PLFS regression on " + str(os.getenv('HOSTNAME'))
            + ": " + str(r_status) + "\" " + str(options.email_addr))
        try:
            os.remove(email_file)
        except OSError:
            print ("Check_results.py Warning: problem removing " + str(email_file)
                + ". Continuing...")

    # Remove the id file if we were to wait. This file is also the lock file for
    # a regression run, so removing it allows future regression instances to run.
    if options.sub_id_file != None:
        print ("Removing id file " + str(options.sub_id_file))
        try:
            os.remove(options.sub_id_file)
        except OSError:
            print ("Check_tests.py Error: unable to remove "
                + str(options.sub_id_file)
                + ". Future instances of the regression will not start.")

    # If we are using a logfile for output, put stdout/err back to normal before exiting
    if options.logfile != None:
        sys.stdout = old_stdout
        sys.stderr = old_stderr
        f.close()
    return status


if __name__ == "__main__":
    sys.exit(main())
