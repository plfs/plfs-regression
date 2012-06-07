#include "plfs.h"
#include <unistd.h>
#include <stdio.h>


int main(int argc, char **argv){
//
// How to implement this in regression
// Use util function to get mountpoint and append user directory to it
// Run the checks on the full path:q
//
//
//

//  printf("plfs access %s: %d\n","/Users", plfs_access("/Users", 0700));
//  printf("plfs access %s: %d\n","/mnt", plfs_access("/mnt", 0700));
//  printf("plfs access %s: %d\n","/mnt/plfs", plfs_access("/mnt/plfs", 0700));
//  printf("plfs access %s: %d\n","/Users", plfs_access("/Users", 0700));

  char *path;
  if (argc > 1) {
      path = strdup(argv[1]);
  }  
  else {
      printf("ERROR:  No path specified\n");
      return 1;
  }
  printf("plfs access %s: %d\n",path, plfs_access(path, R_OK));
//  printf("plfs access %s: %d\n","/var/tmp", plfs_access("/var/tmp", R_OK));
//  printf("plfs access %s: %d\n","/var", plfs_access("/var", R_OK));
//  printf("plfs access %s: %d\n","/var/tmp", plfs_access("/var/tmp", R_OK));
//  printf("plfs access %s: %d\n","/var/tmp/plfs.atorrez", plfs_access("/var/tmp/plfs.atorrez", R_OK));
//  printf("plfs access %s: %d\n","/var/tmp/plfs.atorrez/atorrez", plfs_access("/var/tmp/plfs.atorrez/atorrez", R_OK));
//  printf("plfs access %s: %d\n","/var/tmp/plfs.atorrez/atorrez/x:", plfs_access("/var/tmp/plfs.atorrez/atorrez/x", R_OK));
  return 0;
}
