/*
Author: David Shrader

file: replace_char.c

This simple program will replace a single character on a random line
in an output file from fs_test. The -touch 3 and -check 3 options must
have been used when creating the file.
*/

#include <stdio.h>
#include <stdlib.h>

int main(int argc, char *argv[]){
    if (argc != 3){
        printf("Usage: %s filename char\n", argv[0]);
        printf("\nFilename is the output file to parse, char is ");
        printf("the character that will replace a random character ");
        printf("on a random line in filename.\n");
        return 1;
    }

    FILE *file;
    char *line = NULL;
    size_t line_size = 0;
    ssize_t read;

    char rep_string[] = "abcdefghijklmnopqrstuvwxyz";
    // The following calculation will return a length of one more than
    // the number of elements just put in rep_string due to the \0 at the
    // end which is automatically placed there for char arrays. So the
    // actual number of useful characters in rep_string will be
    // rep_string_len - 1.
    int rep_string_len = sizeof(rep_string) / sizeof(rep_string[0]);
    char replacee;
    char *replacer = argv[2];
    long count = 0;
    long lineno = 0;
    fpos_t pos, prev;
    time_t seed;
    unsigned char ch;

    if ((file = fopen(argv[1], "r+")) == NULL){
        printf("Unable to open file %s\n", argv[1]);
        return 1;    
    }
    fgetpos(file, &prev);

    // Get a seed for the random number generator. Print it out.
    seed = time(NULL);
    printf("Seed for random number generation: %ld\n", seed);
    srand(seed);

    // Choose a line to replace. Each line has the same probability to be
    // chosen.
    while((read = getline(&line, &line_size, file)) != -1){
        if((rand() % (count + 1)) == 0){
            pos = prev;
            lineno = count + 1;
        }
        fgetpos(file, &prev);
        count += 1;
        //printf("Line: %s", line);
    }

    if (line){
        free(line);
    }

    printf("Line to be changed: %ld\n", lineno);

    // Choose which character to replace
    replacee = rep_string[rand() % (rep_string_len - 1)];
    printf("Character that will be replaced: %c\n", replacee);
    printf("Character will be replaced by: %s\n", replacer);

    // Go back to the line that was chosen
    fsetpos(file, &pos);
    prev = pos;
    // Loop through the characters in the line looking for the character
    // to change.
    while((ch = fgetc(file)) && (ch != '\n')){
        //printf("got character %c\n", ch);
        if(ch == replacee){
            pos = prev;
            break;
        }
        fgetpos(file, &prev);
    }

    // Back up one character and write out the replacement.
    fsetpos(file, &pos);
    fprintf(file, "%s", replacer);

    fclose(file);
    return 0;
}
