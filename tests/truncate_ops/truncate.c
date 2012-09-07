#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>

int Stat(const char *path, int expected) {

    int success = 0;
    struct stat stbuf;
    stat(path, &stbuf);
    printf("%s is size %ld\n", path, stbuf.st_size);
    if (stbuf.st_size == expected) {

        success == 1;

    } else {

        success == 0;
        printf("ERROR: Size should be %ld, is %ld\n",

            (long)expected, (long)stbuf.st_size);

        exit(1);

    }
    return success;

}

int main(int argc, char **argv){

    int out, rc;
    char *path; 
    char map_cmd[128];


    if ( argc > 1 ) {
        path = strdup(argv[1]);
    }
    else {
       printf("ERROR: Target path and filename not specified\n");
       printf("Usage:  ./truncate /path/filename\n");
       return 1;
    }

//    first make sure we can truncate to offset 0
//    printf("truncate 0\n");
    printf("truncating %s to offset 0\n", path);
    out=open(path, O_WRONLY | O_CREAT | O_TRUNC, S_IRWXU );
    if ( out < 0 ) {
        printf("Error:  Failed on file open\n");
    }
    close(out);
    rc=truncate(path,0);
    if ( rc < 0) {
        printf("Error: Truncate to offset 0 failed\n");
    }
    rc=truncate(path,0);
    if ( rc < 0) {
        printf("Error: Truncate to offset 0 failed\n");
    }
    sprintf(map_cmd, "plfs_map %s", path);
    system(map_cmd);
    Stat(path,0);
    
//    now make sure we can write zero bytes
//    printf("write0\n");
    printf("writing 0 bytes to %s\n", path);
    system("rm path");
    out=open(path,O_WRONLY|O_CREAT|O_TRUNC,S_IRWXU);
    if ( out < 0 ) {
        printf("Error:  Failed on file open\n");
    }
    rc=pwrite(out,"foo",0,0);
    if ( rc < 0 ) {
        printf("Error:  Failed on file write of zero bytes.\n");
    }
    rc=pwrite(out,"foo",0,0);
    if ( rc < 0 ) {
        printf("Error:  Failed on file write of zero bytes.\n");
    }
    close(out);
    sprintf(map_cmd, "plfs_map %s", path);
    system(map_cmd);
    Stat(path,0);
    
//    now make sure we can truncate to offset N to grow
//    printf("truncate100\n");
    printf("truncating %s to offset 100\n", path);
    out=open(path,O_WRONLY|O_CREAT|O_TRUNC,S_IRWXU);
    if ( out < 0 ) {
        printf("Error:  Failed on file open\n");
    }
    close(out);
    rc=truncate(path,100);
    if ( rc < 0) {
        printf("Error: Truncate to offset 100 failed\n");
    }
    rc=truncate(path,100);
    if ( rc < 0) {
        printf("Error: Truncate to offset 100 failed\n");
    }
    sprintf(map_cmd, "plfs_map %s", path);
    system(map_cmd);
    Stat(path,100);
    
//    now make sure we can truncate to offset N to shrink
//    printf("write3,truncate2\n");
    printf("writing 3 bytes of data to %s then truncating to offset 1\n", path);

    out=open(path,O_WRONLY|O_CREAT|O_TRUNC,S_IRWXU);
    if ( out < 0 ) {
        printf("Error:  Failed on file open\n");
    }
    rc=pwrite(out,"foo",3,0);
    if ( rc < 0) {
        printf("Error:  Failed on file write\n");
    }
    close(out);
    rc=truncate(path,1);
    if ( rc < 0) {
        printf("Error: Truncate to offset 1 failed\n");
    }
    rc=truncate(path,1);
    if ( rc < 0) {
        printf("Error: Truncate to offset 1 failed\n");
    }
    sprintf(map_cmd, "plfs_map %s", path);
    system(map_cmd);
    Stat(path,1);
    
//    now make sure we can overwrite a file
    printf("Overwriting file $s\n", path);
    out=open(path,O_WRONLY|O_CREAT|O_TRUNC,S_IRWXU);
    if ( out < 0 ) {
        printf("Error:  Failed on file open\n");
    }
    rc=pwrite(out,"foo",3,0);
    if ( rc < 0) {
        printf("Error:  Failed on file write\n");
    }
    close(out);
    out=open(path,O_WRONLY|O_CREAT,S_IRWXU);
    if ( out < 0 ) {
        printf("Error:  Failed on file open\n");
    }
    rc=pwrite(out,"bar",3,2);
    if ( rc < 0) {
        printf("Error: Overwrite of file failed\n");
    }
    close(out);
    sprintf(map_cmd, "plfs_map %s", path);
    system(map_cmd);
    Stat(path,5);
    unlink(path);
    exit(0);
    
    return 0;
    
}
    
