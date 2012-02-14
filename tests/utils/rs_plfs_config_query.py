#!/usr/bin/env python
#
# Common functions related to mount points

import subprocess,re,sys
from optparse import OptionParser

def get_mountpoint_name(line):
    """Returns the mount point name from plfs_check_config's output

    Input:
        line: a line containing "Mount Point"
    Output:
        a single string containing the path of the mount point
    """
    # Remove a trailing colon.
    mline = re.sub(':[\s]*$', '', line)
    # The mount point's path should be the last element on the line.
    return (mline.split())[-1]

def strip_trailing_slashes(path):
    """Returns a version of path that has all trailing slashes removed.

    Input:
        path: a path
    Output:
        a string will all trailing slashes removed from path.
    """
    return re.sub('/*$', '', path)

def call_plfs_check_config(ignore_errors=False):
    """Calls and captures the output of plfs_check_config

    Input:
        ignore_erros: flag to ignore exit status and errors returned by
            plfs_check_config.
    Output:
        Either an empty list if there was a problem running plfs_check_config
        or a list formated just as subprocess.communicate() returns
    """
    if ignore_errors == False:
        ps = subprocess.Popen(['plfs_check_config'], stdin=None, 
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    else:
        # plfs_check_config will report a single error for every directory
        # that does not exist. This breaks up the flow of the output that
        # we want to parse. Remove them so that we get what we expect to be
        # able to parse.
        ps = subprocess.Popen(['plfs_check_config | grep -v Error'],
            stdin=None, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            shell=True)
    output = ps.communicate()
    if ps.returncode != 0 and ignore_errors == False:
        print ("Error: plfs_check_config returned with exit code " 
            + str(ps.returncode))
        print ("Standard output from plfs_check_config:")
        print str(output[0])
        print ("Standard error from plfs_check_config:")
        print str(output[1])
        return []
    else:
        return output

def get_mountpoints(ignore_errors=False):
    """Determine plfs mount points by calling plfs_check_config.

    Input:
        ignore_errors: flag to ignore errors from plfs_check_config
    Output:
        a python list containing a string for each mount point found
    """
    mount_points = []
    output = call_plfs_check_config(ignore_errors=ignore_errors)
    if output != []:
        # Split stdout into lines and loop over them, looking for lines
        # with mount points in them.
        stdout = output[0].split('\n')
        for line in stdout:
            if ("Mount Point" in line):
                # Get the mount point's name
                mp = get_mountpoint_name(line)
                # If mp isn't empty, then we got at least a non-empty string
                if mp != '':
                    mount_points.append(mp)

    if len(mount_points) == 0:
        print ("Error: no mount points will be passed back. Either the rc "
            + "files had no mount points in them or there was a problem "
            + "parsing them.")

    return mount_points

def get_backends(mount_point, ignore_errors=False):
    """Determine a list of backends associated with a plfs mount point

    Input:
        mount_point: the mount point to find backends for
        ignore_errors: flag to ignore errors from plfs_check_config
    Output:
        a python list containing a string for each backend
    """
    mount_point = strip_trailing_slashes(mount_point)
    backends = []
    mp = ""
    output = call_plfs_check_config(ignore_errors=ignore_errors)
    if output != []:
        # Split stdout into lines and loop over them, looking for lines
        # with mount points and backends in them.
        stdout = output[0].split('\n')
        for line in stdout:
            # Watch for each mount point section and keep track of the
            # current section
            if ("Mount Point" in line):
                # Remove a trailing ':'
                mp = get_mountpoint_name(line)
                #print mp
            # If Backend: is in the line, see if we're in the right mount
            # mount point section
            elif ("Backend:" in line):
                if mp == mount_point:
                    # The path of the backend is the last element on the line
                    be = (line.split())[-1]
                    if be != '':
                        backends.append(be)
            # We've hit a line that has neither Mount Point or Backend in it.
            # If we already found the mount point in question and got to
            # another line after the "Backend:" lines, then we're done.
            # Otherwise, we need to keep parsing.
            else:
                if mp == mount_point:
                    break
                else:
                    continue
    if len(backends) == 0:
        print ("Error: no backends will be passed back. Either the rc "
            + "files had no mount points in them or there was a problem "
            + "parsing them.")

    return backends

def parse_args(argv):
    """Parse command line arguments if this module is called from the shell
    """
    usage = "\n %prog -m [-i]\n %prog -b [-i] mount_point"
    description = ("This script queries a PLFS configuration and returns a "
        + "space-separated list of the requested parameter. It uses PLFS's "
        + "plfs_check_config to parse the PLFS config files. Either -m or -b "
        + "must be specified, but not both.")
    parser = OptionParser(usage=usage, description=description)

    parser.add_option("-m", "--get-mountpoints", action="store_true",
        dest="get_mountpoints", help="Request a list of the PLFS mount points "
        + "from the PLFS configuration.", default=False)
    parser.add_option("-b", "--get-backends", action="store_true",
        dest="get_backends", help="Request a list of the PLFS backends "
        + "associated with the specified PLFS mount point. The mount point "
        + "must be given on the command line.", default=False)
    parser.add_option("-i", "--ignore-errors", action="store_true",
        dest="ignore_errors", help="Ignore errors and exit status of "
        + "plfs_check_config. Userful for just finding the names of the "
        + "needed PLFS directories.", default=False)

    (options, args) = parser.parse_args()
    if options.get_mountpoints == False and options.get_backends == False:
        parser.error("At least -m or -b is required. Use -h or --help "
            + "for help.")
    if options.get_mountpoints == True and options.get_backends == True:
        parser.error("Both -m and -b cannot be specified at the same time. "
            + "Use -h or --help for help.")

    if options.get_backends == True and len(args) != 1:
        parser.error("A non-optional parameter is required when using -b. "
            + "Use -h or --help for help.")

    return options, args

def print_list_as_string(list, delim=' '):
    """Prints a string using all elements of a python list separated by an
    optional delimitor

    Input:
        list: python list
        delim: delimitor; default is a single white space
    Output:
        a string that is a delim-separated representation of list
    """
    ret_str = str(list[0])
    for i in list[1:]:
        ret_str = str(ret_str) + str(delim) + str(i)
    return ret_str

def main(argv=None):
    """The main method that is used when this script is called from the shell.
    """
    if argv == None:
        argv = sys.argv
    options,args = parse_args(argv)
    if options.get_mountpoints == True:
        ret_list = get_mountpoints(ignore_errors=options.ignore_errors)
    if options.get_backends == True:
        ret_list = get_backends(ignore_errors=options.ignore_errors, 
            mount_point=args[0])
    if len(ret_list) == 0:
        return 1
    else:
        ret_str = print_list_as_string(ret_list)
        print ret_str
        return 0

if __name__ == "__main__":
    sys.exit(main())
