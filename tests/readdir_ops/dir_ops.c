#include <dirent.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

/******************************************************************************
This function is called by main.  It is used to read a directory and determine
if the passed in filename if found in the directory
*******************************************************************************/
int read_directory(struct dirent *f_ptr, DIR *d_ptr, char *tgt_file)
{
   int file_found=0;
   // read the directory
   while ((f_ptr = readdir(d_ptr)) != NULL) {
       //printf("file in d directory %s\n", f_ptr->d_name);
       // Determine if passed tgt_file matches dir entry
       if (!strcmp(tgt_file,f_ptr->d_name)) {
           file_found=1;
       }
   }
   if (file_found) {
      printf("File found\n");
      return 0;
   }
   else {
      printf("File not found\n");
      return 1;
   }
}


/******************************************************************************
 This function creates a dirctory and file as specified by the input argruments.
 It is used to verify that a file create and delete work as expected.
 The sequence is as follows:
    create directory
    create file in directory
    verify file exists in directory
    remove file
    verify file no longer exists in directory
*******************************************************************************/
int main(int argc, char *argv[])
{
   DIR *dir_ptr;
   struct dirent *file_ptr;
   int dir_status;
   char *path;
   char *filename;
   FILE *test_file_ptr;
   char full_path[128];
   int read_return;
   int dir_remove;
   int return_value=0;


   // Input arguments are directory and filename
   if (argc > 2) {
       path = strdup(argv[1]);
       filename = strdup(argv[2]); 
       sprintf(full_path,"%s/%s",path,filename);
       printf("%s\n", full_path);  
   }
   else {
       printf("ERROR: Path and/or file not specified\n");
       printf("Usage:  ./readdir_test path filename\n");
       return 1;
   }

   // Make the directory
   if ((dir_status=mkdir(path, S_IRWXU))== 0) {
     printf("Directory created\n");
   } 

   // Open the directory
   if ((dir_ptr = opendir(path)) == NULL) {
     printf("Error:  Could not open directory\n");
     return_value=1;
   }
   // Create a file
   else {
     printf("Going to create file %s\n", full_path);
     test_file_ptr = fopen(full_path, "w");
     if (test_file_ptr == NULL) {
        printf("Error:  NULL returned on file create \n");
       return_value=1;
     }    
     else {
       printf("Successfully created file\n");
       // close the directory and file
       fclose(test_file_ptr);
       closedir(dir_ptr);
     }
   }
   // Open the directory again}
   if ((dir_ptr = opendir(path)) == NULL) {
     printf("Error:  Could not open directory\n");
       return_value=1;
   }
   printf("Going to read directory %s to make sure file %s found %s\n", path,filename);
   read_return = read_directory(file_ptr, dir_ptr, filename);
   // File should be found in directory
   if (read_return != 0) {
       printf("Error: expected file %s to be present but was not\n", full_path);  
       return_value=1;
   }
   // Delete the file
   printf("Going to delete %s\n", full_path);
   unlink(full_path);
   printf("Reading directory after deleteing file %s\n", full_path);
   rewinddir(dir_ptr);

   // File should no longer be present
   read_return = read_directory(file_ptr, dir_ptr, filename);
   if (read_return == 0) {
       printf("Error: expected file %s to not be present but was\n", full_path);  
       return_value=1;
   }
   closedir(dir_ptr);
   dir_remove = rmdir(path);
   if (dir_remove != 0) {
      printf("Error: Directoy %s cannot be removed\n",path);
   }    
   return return_value;
}
