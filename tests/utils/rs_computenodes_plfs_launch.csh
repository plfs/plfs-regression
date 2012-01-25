#! /bin/tcsh
#
# Input values:
# Please see the output of -h or --help.
#
# Exit Values:
# 0: Successfully mounted or unmounted
# 1: Mounting/unmounting unsuccessful
# 2: Mount point is already mounted on all nodes when trying to mount

# Defaults
set plfs   = "" 
set pexec  = ""
set mnt_pt  = ""
set umount = 0
set plfs_lib = ""
set force_remount = 0

set script_name = `basename $0`

# Catch whatever command line parameters there may be
foreach i ($argv)
  switch ($i)
    case --plfs=*:
      set plfs = `echo $i | sed 's/[-a-zA-Z0-9]*=//'`
      echo "Using $plfs"
      breaksw
    case --pexec=*:
      set pexec = `echo $i | sed 's/[-a-zA-Z0-9]*=//'`
      echo "Using $pexec"
      breaksw
    case --mntpt=*:
      set mnt_pt = `echo $i | sed 's/[-a-zA-Z0-9]*=//'`
      echo "Using $mnt_pt"
      breaksw
    case umount:
      set umount = 1
      breaksw
    case --plfslib=*:
      set plfs_lib = `echo $i | sed 's/[-a-zA-Z0-9]*=//'`
      echo "Using $plfs_lib"
      breaksw
    case --force-remount:
      set force_remount = 1
      breaksw
    case -h:
    case --help:
      echo "${script_name}: mount plfs mount points on compute nodes associated"
      echo "with a running job."
      echo ""
      echo "Usage:"
      echo "$script_name --plfs=FILE --pexec=FILE --mntpt=DIR [OPTIONS ...]"
      echo ""
      echo "This script will attempt to mount plfs mount points on all hosts"
      echo "that are attached to a Moab job (uses PBS_NODEFILE)."
      echo ""
      echo "Required parameters:"
      echo "\t--plfs=FILE"
      echo "\t\tSet the location of the plfs executable to FILE."
      echo "\t--pexec=FILE"
      echo "\t\tSet the location of the pexe executable to FILE."
      echo "\t--mntpt=DIRECTORY"
      echo "\t\tSet the location of the mount point to pass to plfs. This script"
      echo "\t\twill try to create DIRECTORY if it does not exist."
      echo "OPTIONS"
      echo "\t--plfslib=DIRECTORY"
      echo "\t\tSet the location of the plfs library. Use to make sure a"
      echo "\t\tconsistent set of plfs binary and library are used together."
      echo "\t\tWhen this option is used, due to limitations of shell scripting,"
      echo "\t\ta script must be created to properly set LD_LIBRARY_PATH and"
      echo "\t\tthen call plfs. This script must be copied to all nodes (done"
      echo "\t\twith pexec --scp) and then executed via pexec."
      echo "\t--force-remount"
      echo "\t\tThe default behavior if all nodes already have the mount point"
      echo "\t\tmounted is to not do anything. Setting this option forces this"
      echo "\t\tscript to attempt to unmount and then remount the mount point."
      echo "\tumount"
      echo "\t\tUnmount the plfs mount points"
      echo "\t-h|--help"
      echo "\t\tDisplay this message"
      exit 0
      breaksw
    default:
      echo "Unknown command line parameter $i. Type --help for usage information."
      exit 1
      breaksw
  endsw
end

if ( "$plfs" == "" ) then
  echo "--plfs value is emtpy. Please use -h|--help for help."
  exit 1
endif
if ( "$pexec" == "" ) then
  echo "--pexec value is empty. Please use -h|--help for help."
  exit 1
endif
if ( "$mnt_pt" == "" ) then
  echo "--mntpt value is empty. Please use -h|--help for help."
  exit 1
endif

if ( -x $plfs ) then
  echo "$plfs is a valid executable"
else
  echo "$plfs is not a valid executable. Exiting."
  exit 1
endif

if ( "$plfs_lib" != "" ) then
  if ( ! -d "$plfs_lib" ) then
    echo "$plfs_lib is not a valid directory. Exiting."
    exit 1
  endif
endif

set mount  = "$plfs $mnt_pt -o direct_io" 

if ( -x "$pexec" ) then
    # Figure out the number of nodes in the allocation
    set num_nodes = 0
    if ( $?PBS_NUM_NODES ) then # PBS/torque
        set num_nodes = $PBS_NUM_NODES
    else if ( $?PBS_JOBID ) then
        # It seems older versions of PBS/torque don't have PBS_NUM_NODES. So,
        # to get it from moab. Don't just use 'mjobctl -q hostlist' to get a
        # list of nodes because, depending on the configuration of the machine,
        # the names in that list may not be acceptable names to use in ssh 
        # (which is what this script uses).
        set num_nodes = `mjobctl -q hostlist $PBS_JOBID | tr ',' '\n' | grep -v '^$'  | wc -l`
    else if ( $?SLURM_JOB_NUM_NODES ) then # SLURM
        set num_nodes = $SLURM_JOB_NUM_NODES
    else if ( $?SLURM_JOB_ID ) then
        set num_nodes = `mjobctl -q hostlist $SLURM_JOB_ID | tr ',' '\n' | grep -v '^$'  | wc -l`
    endif
    
    # See if we got an acceptable number of nodes.
    if ( $num_nodes == 0 ) then
        echo "Unable to determine the number of nodes in the allocation. Exiting."
        exit 1
    endif
    # num_nodes should now have the number of nodes in the allocation
    # Get the directory name for this script so that we know how to call the
    # wrapper script script that will get the proper runcommand from
    # experimenet_management's config file.
    set dir = `dirname $0`
    set runcommand = `$dir/rs_exprmgmtrc_option_value.py runcommand`
    if ( $status != 0 ) then
        echo "Unable to find the correct run command from experiment_management. Exiting."
        exit 1
    endif
    # We have the runcommand, we have the number of nodes. Construct a command
    # to get all the hostnames
    set node_file = "/tmp/${USER}.node_file"
    if ( "$runcommand" == "mpirun" ) then
        set mpi_command = "$runcommand -n $num_nodes -bynode"
    else if ( "$runcommand" == "aprun" ) then
        set mpi_command = "$runcommand -q -n $num_nodes -N 1"
    else
        echo "Unknown runcommand: $runcommand. Exiting."
        exit 1
    endif
    set command = "$mpi_command hostname >& $node_file"
    # Run the command
    #$command
    $mpi_command hostname | grep -v "^Reported" >& $node_file
    if ( $status != 0 ) then
        echo "Problem executing $command. Exiting."
        rm -f $node_file
    endif
    set nodes = `uniq $node_file | tr '\n' ','`
    # Remove the temporary node_file
    rm -f $node_file
    echo "# pexec : $pexec"
    set pexec = "$pexec -pP 32 -m $nodes --all --ssh"
    echo "# mnt_pt : $mnt_pt"
    echo "# plfs : $plfs"
    echo "# mount : $mount"
    echo "# nodes : $nodes"
    # If we're mounting, need to check if it is already mounted. If all nodes
    # already have it mounted, just exit unless we are forcing a remount.
    if ( $umount == 0 ) then
        $pexec grep -a Uptime $mnt_pt/.plfsdebug >>& /dev/null
        if ( $status == 0 ) then
            echo "# Mount point $mnt_pt already mounted on all nodes."
            if ( $force_remount == 0 ) then
                exit 2
            endif
        endif
    endif
    # At least one of the nodes doesn't have the mount point mounted or
    # we're unmounting
    echo "# unmount any existing mount points"
    $pexec "fusermount -u $mnt_pt |& grep -vi tput"
    # Now mount if we need to.
    if ( $umount == 0 ) then
        $pexec "mkdir -p $mnt_pt |& grep -vi tput" 
        echo "# mounting plfs"
        if ( "$plfs_lib" != "" ) then
            # Need to modify LD_LIBRARY_PATH before calling the mount command, but
            # both commands have to be done in the same subshell. Also need to use
            # a specific shell as the syntax to change an environment variable is
            # not shared across shells.
            $pexec '/bin/bash -c "export LD_LIBRARY_PATH='${plfs_lib}':$LD_LIBRARY_PATH; '${mount}'"' |& grep -vi tput
        else
            $pexec $mount |& grep -vi tput
        endif
    endif
    echo "# checking plfs"
    if ( $umount == 0 ) then
        # Check that everything is mounted since we're mounting.
        $pexec "grep -a Uptime $mnt_pt/.plfsdebug | grep -vi Tput"
        set ret = $status
    else
        # We're unmounting. Check that nothing is mounted.
        $pexec 'cat '$mnt_pt'/.plfsdebug |& grep "No such file or directory"'
        set ret = $status
    endif
    if ( $ret != 0 ) then
        exit 1
    endif
else 
    echo "$pexec is not a valid executable. Exiting."
    exit 1
endif
exit 0
