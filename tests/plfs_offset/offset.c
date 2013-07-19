#include <stdio.h>
#include <stdlib.h>
#include "plfs.h"
#include <fcntl.h>
#include <pthread.h>

// This test verifies plfs API open,write,read, and close.  It also verifies offset 
// writes and reads.

int main(int argc, char **argv)
{
plfs_error_t ret_value;
char write_buf1[] = "Testing";
char write_buf2[] = "PLFSRW";
char *read_buf = (char *) malloc(sizeof(write_buf1)+sizeof(write_buf2));
Plfs_fd * pfd = NULL;
char *path;
ssize_t bytes;
int num_refs;

if (argc >1 && argc < 3) {
    path = strdup(argv[1]);
}
else {
    printf("Error:  No path specified or too many arguments\n\n");
    printf("Usage:  ./offset path/file \n");
    return(10);
}

// Test 1:  Create file
if((plfs_open(&pfd, path, O_CREAT|O_TRUNC|O_RDWR, 99, 0666, NULL)) != PLFS_SUCCESS )
{
   perror("Error opening file - Test 1");
   return(1);
}

// Test 2:  write file 6 bytes at offset 0
if((ret_value = plfs_write(pfd, write_buf1, 6, 0, 99, &bytes)) != PLFS_SUCCESS || bytes != 6 ) //6 bytes at offset 0
{
   perror("Error in first write - Test 2");
   return(2);
}

// Test 3:  write file 5 bytes at offset 6 
if((ret_value = plfs_write(pfd, write_buf2, 5, 6, 99, &bytes)) != PLFS_SUCCESS || bytes != 5 ) //5 bytes at offset 6
{
   perror("Error in second write - Test 3");
   return(3);
}

// Test 4:  close file 
if((plfs_close(pfd, 99, 99, O_CREAT|O_TRUNC|O_RDWR, NULL, &num_refs)) != PLFS_SUCCESS )
{
   perror("Error closing file - Test 4");
   return(4);
}

// Test 5:  Open File
pfd = NULL;
if((plfs_open(&pfd, path, O_RDWR, 99, 0666, NULL)) != PLFS_SUCCESS )
{
   perror("Error during re-open - Test 5");
   return(5);
}

// Test 6:  read file 11 bytes at at offset 0
if((ret_value = plfs_read(pfd, read_buf, 11, 0, &bytes)) != PLFS_SUCCESS || bytes != 11 )
{
   perror("Error during read - Test 6");
   return(6);
}

// Test 7: close file
if((plfs_close(pfd, 99, 1, O_RDWR, NULL, &num_refs)) != PLFS_SUCCESS )
{
perror("Error re-closing file -  Test 7");
exit(7);
}

free(read_buf);
return 0;

}
