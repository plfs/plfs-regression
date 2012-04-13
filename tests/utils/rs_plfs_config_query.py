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
    ps = subprocess.Popen(['plfs_check_config'], stdin=None, 
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
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

def get_mountpoints(ignore_errors=False, mp_type=None):
    """Determine plfs mount points by calling plfs_check_config.

    Input:
        ignore_errors: flag to ignore errors from plfs_check_config
        mp_type: the type of mount points to look for. Can be shared_file,
            n-1, file_per_proc, or n-n.
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
                # We also only append here if we're not checking mount point
                # types
                if mp != '' and mp_type == None:
                    mount_points.append(mp)
            elif ("Expected Workload" in line) and mp_type != None:
                # This is a line that specifies the type of mount point.
                # Get the type only if we are checking mount point types. It
                # should be the second to last element
                this_mptype = (line.split())[-2]
                # The types that can be seen from plfs_check_config's output
                # are only shared_file or file_per_proc. If there is a match,
                # the last mount_point seen is a mount_point we want to pass
                # back.
                if this_mptype == "shared_file":
                    if mp_type == this_mptype or mp_type == "n-1":
                        mount_points.append(mp)
                elif this_mptype == "file_per_proc":
                    if mp_type == this_mptype or mp_type == "n-n":
                        mount_points.append(mp)
                else:
                    # We got a type that this script doesn't know how to deal
                    # with yet.
                    pass
            else:
                # This is a line we don't need for figuring out mount points
                continue

    if len(mount_points) == 0:
        print ("Error: no mount points will be passed back. Either there was "
            + "a problem parsing the rc files or there were no mount points "
            + "of the requested type.")

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
                # Get the mount point's name
                mp = get_mountpoint_name(line)
                #print mp
            # If Backend: is in the line, see if we're in the right mount
            # mount point section
            elif ("Backend:" in line):
                if mp == mount_point:
                    # Append the mount point to the list.
                    # The path of the backend is the last element on the line
                    be = (line.split())[-1]
                    if be != '':
                        backends.append(be)
            elif ("Checksum:" in line):
                # We've reached the end of a mount point's section
                if mp == mount_point:
                    # We've reached the end of the mount point we are
                    # looking for
                    break
            else:
                # A line that has no information that we need to find backends
                continue
    if len(backends) == 0:
        print ("Error: no backends will be passed back. There was a problem "
            + "parsing the rc files.")

    return backends

def parse_args(argv):
    """Parse command line arguments if this module is called from the shell
    """
    usage = "\n %prog -m [-i] [-t MP_TYPE]\n %prog -b [-i] mount_point"
    description = ("This script queries a PLFS configuration and returns a "
        + "space-separated list of the requested parameter. It uses PLFS's "
        + "plfs_check_config to parse the PLFS config files. Either -m or -b "
        + "must be specified, but not both.")
    parser = OptionParser(usage=usage, description=description)

    parser.add_option("-m", "--get-mountpoints", action="store_true",
        dest="get_mountpoints", help="Request a list of the PLFS mount points "
        + "from the PLFS configuration.", default=False)
    parser.add_option("-t", "--mptype", dest="mp_type", help="Request a type "
        + "of mount point to return. Valid options are shared_file, n-1, "
        + "file_per_proc, or n-n. Default is to return all mount points, "
        + "regardless of type.", default=None)
    parser.add_option("-b", "--get-backends", action="store_true",
        dest="get_backends", help="Request a list of the PLFS backends "
        + "associated with the specified PLFS mount point. The mount point "
        + "must be given on the command line.", default=False)
    parser.add_option("-i", "--ignore-errors", action="store_true",
        dest="ignore_errors", help="Ignore errors and exit status of "
        + "plfs_check_config. Userful for just finding the names of the "
        + "needed PLFS directories.", default=False)

    (options, args) = parser.parse_args(argv)
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
        argv = sys.argv[1:]
    options,args = parse_args(argv)
    if options.get_mountpoints == True:
        ret_list = get_mountpoints(ignore_errors=options.ignore_errors, mp_type=options.mp_type)
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
