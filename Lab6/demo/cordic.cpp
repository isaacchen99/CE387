

#include <stdio.h>
#include <stdlib.h>
#include <math.h>


using namespace std;


// quantization
#define BITS            16
#define QUANT_VAL       (1 << BITS)
#define QUANTIZE_F(f)   (int)(((float)(f) * (float)QUANT_VAL))
#define QUANTIZE_I(i)   (int)((int)(i) * (int)QUANT_VAL)
#define DEQUANTIZE_I(i)   (int)((int)(i) / (int)QUANT_VAL)
#define DEQUANTIZE_F(i)   (float)((float)(i) / (float)QUANT_VAL)

// Cordic constants generated with the following code:
//      for ( i = 0; i < n; i++ )
//      {
//          CORDIC_TABLE[i] = QUANTIZE_F( atan(pow(2, -i)) );
//      }

#define CORDIC_NTAB 16
static const short CORDIC_TABLE[] =
{
    0x3243, 0x1DAC, 0x0FAD, 0x07F5, 0x03FE, 0x01FF, 0x00FF, 0x007F, 
    0x003F, 0x001F, 0x000F, 0x0007, 0x0003, 0x0001, 0x0000, 0x0000
};



// Cordic in 16 bit signed fixed point math
// Function is valid for arguments in range -pi/2 : pi/2
// for values pi/2 : pi, value = half_pi-(theta-half_pi) and similarly for values -pi : -pi/2

// Constants
#define K           1.646760258121066
#define CORDIC_1K   QUANTIZE_F(1/K)   
#define PI          QUANTIZE_F(M_PI)
#define TWO_PI      QUANTIZE_F(M_PI*2.0) 
#define HALF_PI     QUANTIZE_F(M_PI/2.0)

void cordic_stage(short k, short c, short *x, short *y, short *z)
{
    // inputs
    short xk = *x;
    short yk = *y;
    short zk = *z;

    // cordic stage
    short d = (zk >= 0) ? 0 : -1;
    short tx = xk - (((yk >> k) ^ d) - d);
    short ty = yk + (((xk >> k) ^ d) - d);
    short tz = zk - ((c ^ d) - d);

    // outputs
    *x = tx; 
    *y = ty; 
    *z = tz;    
}

void cordic(int rad, short *s, short *c)
{
    short x = CORDIC_1K;
    short y = 0;
    int r = rad;

    while ( r > PI  ) r -= TWO_PI;
    while ( r < -PI ) r += TWO_PI;

    if ( r > HALF_PI )
    {
        r -= PI;
        x = -x;
        y = -y;
    }
    else if ( r < -HALF_PI )
    {
        r += PI;
        x = -x;
        y = -y;
    }

    short z = r;

    for ( int k = 0; k < CORDIC_NTAB; k++ )
    {
        cordic_stage(k, CORDIC_TABLE[k], &x, &y, &z);
    }  
    
    *c = x; 
    *s = y;
}


int main(int argc, char **argv)
{
    FILE * rad_file = fopen("rad.txt", "w");
    FILE * sin_file = fopen("sin.txt", "w");
    FILE * cos_file = fopen("cos.txt", "w");
    if ( sin_file == NULL || cos_file == NULL )
    {
        printf("Unable to open file.\n");
        return 0;
    }    

    float k = 1.0;
    for ( int i = 0; i < CORDIC_NTAB; i++ )
    {
        //printf("%8.8f\t%08x\n", (float)atan(pow(2, -i)), QUANTIZE_F(atan(pow(2, -i))) );
/*
        float alpha = (float)atan(pow(2, -i));
        float alpha_2 = pow(alpha,2);
        float t = 1.0f + alpha_2;
        f *= pow(t,0.5);
        printf("%8.8f\t%8.8f\t%8.8f\t%8.8f\n", alpha, alpha_2, t, f);

        float x = 1 + pow(2,-2*i);
        float t = pow(x,0.5);
        f *= t;
         printf("%8.8f\t%8.8f\t%8.8f\n", x, t, f);
*/

        k *= sqrt(1.0 + pow(2,-2*i));
        printf("%8.8f\t(%8.8f)\n", k, (K-k));
    }

    printf("theta\trads\tsin\tc_sin\tsin_err\tcos\tc_cos\tcos_err\n");

    for ( int i = -360; i <= 360; i++ )
    {
        float p = i * M_PI / 180;        
        int p_fixed = QUANTIZE_F(p);
        short s = 0, c = 0;
        
        cordic(p_fixed, &s, &c);
        fprintf(rad_file, "%08x\n", p_fixed);
        fprintf(sin_file, "%04x\n", (unsigned short)s);
        fprintf(cos_file, "%04x\n", (unsigned short)c);

        //printf("%d\t%08x\t%8.4f\t%8.4f\t%8.4f\t%8.4f\t%8.4f\t%8.4f\n", i, p_fixed, sin(p), DEQUANTIZE_F(s), (DEQUANTIZE_F(s) - sin(p)), cos(p), DEQUANTIZE_F(c), (DEQUANTIZE_F(c) - cos(p)));
    }           

    fclose( sin_file );
    fclose( cos_file );

    return 0;
}

