#include <stdio.h>

// Compile: g++ vectorsum.c -o vectorsum
// Run: ./vectorsum

void vectorsum ( int *X, int *Y, int *Z, int n )
{
    for ( int i = 0; i < n; i++ ) 
    {
        Z[i] = X[i] + Y[i];
    }
}

int main()
{
    const int n = 64;
    int X[n], Y[n], Z[n];

    // create random inputs
    for (int i = 0; i < n; i++) 
    {
        X[i] = rand();
        Y[i] = rand();
    }

    vectorsum( X, Y, Z, n );
    
    FILE * x_file = fopen(“x.txt”, “w”);
    FILE * y_file = fopen(“y.txt”, “w”);
    FILE * z_file = fopen(“z.txt”, “w”);
    
    for (int i = 0; i < n; i++) 
    {
        fprintf( x_file, “%08x\n”, X[i] );
        fprintf( y_file, “%08x\n”, Y[i] );
        fprintf( z_file, “%08x\n”, Z[i] );
    }
    
    fclose( x_file );
    fclose( y_file );
    fclose( z_file );
    
    return 0;
}
