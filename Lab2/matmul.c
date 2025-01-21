#include <stdio.h>
#include <stdlib.h>

// Compile: gcc -o matmul matmul.c
// Run: ./matmul

void matmul( int N, int A[N][N], int B[N][N], int C[N][N]  ) 
{
    // compute C row-wise
    for ( int i=0; i<N; i++ ) 
    { 
        for ( int j=0; j<N; j++ )
        {
            C[i][j] = 0; 
            for ( int k=0; k<N; k++ )
            {
                //if ( k == 0 ) printf("-----------------\n");
                //printf("%08x + %08x * %08x = %08x\n", C[i][j], A[i][k], B[k][j], (C[i][j] + A[i][k] * B[k][j]) );
                C[i][j] += A[i][k] * B[k][j]; 
            } 
        }
    }
}

int main()
{
    const int n = 8;
    int X[n][n], Y[n][n], Z[n][n];

    // create random inputs
    for (int i = 0; i < n; i++) 
    {
        for (int j = 0; j < n; j++) 
        {
            X[i][j] = rand();
            Y[i][j] = rand();
            Z[i][j] = 0;
        }  
    }

    matmul( n, X, Y, Z );
    
    FILE * x_file = fopen("x.txt", "w");
    FILE * y_file = fopen("y.txt", "w");
    FILE * z_file = fopen("z.txt", "w");
    
    for (int i = 0; i < n; i++) 
    {
        for (int j = 0; j < n; j++) 
        {
            fprintf( x_file, "%08x\n", X[i][j] );
            fprintf( y_file, "%08x\n", Y[i][j] );
            fprintf( z_file, "%08x\n", Z[i][j] );
        }
    }
    
    fclose( x_file );
    fclose( y_file );
    fclose( z_file );
    
    return 0;
}
