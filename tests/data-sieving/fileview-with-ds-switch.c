/*
 * to compile: mpicc me.c -o me
 * to run: mpirun -np 4 ./me file-path
 */

#include <stdio.h>
#include <stdlib.h>
#include "mpi.h"

#define ROW_S 10 
#define COL_S 10

int rank, size;

int main (argc, argv)
    int argc;
    char *argv[];
{
    MPI_File fh;
    MPI_Status status;
    int i,j;
    MPI_Datatype sb_arr;
    MPI_Info info;

    MPI_Init (&argc, &argv);	/* starts MPI */
    MPI_Comm_rank (MPI_COMM_WORLD, &rank);	/* get current process id */
    MPI_Comm_size (MPI_COMM_WORLD, &size);	/* get number of processes */

    // simple test
    if ( argc != 3 ) {
        if ( rank == 0 ) {
            printf("Usage: mpirun -np NProc %s file-path disable_ds/enable_ds\n",
                    argv[0]);
        }
        MPI_Finalize();
        return 0;
    }

    MPI_Info_create(&info);


    if (strcmp(argv[2], "disable_ds") == 0) {
        if( rank == 0 ) {
            printf("Data sieving is DISABLED.\n");
        }
        MPI_Info_set(info, "romio_ds_write", "disable");
    } else {
        if ( rank == 0 ) {
            printf("Data sieving is ENABLED.\n");
        }
        MPI_Info_set(info, "romio_ds_write", "enable");
    }

    MPI_File_open( MPI_COMM_WORLD, argv[1], MPI_MODE_CREATE | MPI_MODE_WRONLY, info, &fh );
    
    MPI_Barrier(MPI_COMM_WORLD);

    int sizes[2] = {ROW_S,COL_S}; // big array has sizes[0] rows and size[1] columns
    int subsizes[2] = {5,5};  //subarray has subsizes[0] rows and subsizes[1] columns
    int starts[2] = {0,0};    //subarray starts at row starts[0] and column starts[1]
    starts[0] = (rank / 2) * 5;
    starts[1] = (rank % 2) * 5;
    printf("starts = (%d, %d).\n", starts[0], starts[1]);

    MPI_Type_create_subarray( 2, sizes, subsizes, starts, MPI_ORDER_C, MPI_CHAR, &sb_arr );
    MPI_Type_commit(&sb_arr);

    
    MPI_File_set_view(fh, 0, MPI_CHAR, sb_arr, "native", MPI_INFO_NULL);
    
    char * p = malloc(100);
    for ( i = 0 ; i < 100 ; i++ ) {
        p[i] = '0'+rank;
    }

    MPI_Offset off;
    MPI_File_get_position( fh, &off );
    printf("Write at %lld\n",  off);
    
    MPI_File_write( fh, p, 1, sb_arr, &status);

    MPI_File_close(&fh);
    MPI_Info_free(&info);
    MPI_Finalize();
    return 0;
}

