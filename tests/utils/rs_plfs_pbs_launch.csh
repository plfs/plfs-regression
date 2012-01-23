#! /bin/tcsh

# Defaults
set plfs   = "" 
set pexec  = ""
set mnt_pt  = ""
set umount = 0
set plfs_lib = ""

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
    case -h:
    case --help:
      echo "plfs_pbs_launch: mount plfs mount points on compute nodes associated"
      echo "with a running job."
      echo ""
      echo "Usage:"
      echo "plfs_pbs_launch --plfs=FILE --pexec=FILE --mntpt=DIR [OPTIONS ...]"
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
    if ( ! -f $PBS_NODEFILE ) then
      echo "Error: No PBS_NODEFILE defined in environment."
      exit 1
    endif
    set nodes = `uniq $PBS_NODEFILE | tr '\n' ','`
    echo "# pexec : $pexec"
    echo $nodes
    set pexec = "$pexec -pP 32 -m $nodes --all --ssh"
    echo "# mnt_pt : $mnt_pt"
    echo "# plfs : $plfs"
    echo "# mount : $mount"
    echo "# nodes : $nodes"
      # always try to unmount first
    echo "# unmount any existing mount points"
    $pexec fusermount -u $mnt_pt |& grep -vi tput
    if ( $umount == 0 ) then
      $pexec mkdir -p $mnt_pt |& grep -vi tput 
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
    $pexec grep -a Uptime $mnt_pt/.plfsdebug | grep -vi Tput
    if (( $status != 0 ) && ( $umount == 0 )) then
      exit 1
    endif
else 
    echo "$pexec is not a valid executable. Exiting."
    exit 1
endif
exit 0
