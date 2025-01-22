#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#define THRESHOLD 50
	

struct pixel {
   unsigned char b;
   unsigned char g;
   unsigned char r;
};

// Read BMP file and extract the pixel values (store in data) and header (store in header)
// data is data[0] = BLUE, data[1] = GREEN, data[2] = RED, etc...
int read_bmp(FILE *f, unsigned char* header, int *height, int *width, struct pixel* data) 
{
	printf("reading file...\n");
	// read the first 54 bytes into the header
   if (fread(header, sizeof(unsigned char), 54, f) != 54)
   {
		printf("Error reading BMP header\n");
		return -1;
   }   

   // get height and width of image
   int w = (int)(header[19] << 8) | header[18];
   int h = (int)(header[23] << 8) | header[22];

   // Read in the image
   int size = w * h;
   if (fread(data, sizeof(struct pixel), size, f) != size){
		printf("Error reading BMP image\n");
		return -1;
   }   

   *width = w;
   *height = h;
   return 0;
}

// Write the grayscale image to disk.
void write_bmp(const char *filename, unsigned char* header, struct pixel* data) 
{
   FILE* file = fopen(filename, "wb");

   // get height and width of image
   int width = (int)(header[19] << 8) | header[18];
   int height = (int)(header[23] << 8) | header[22];
   int size = width * height;
   
   // write the 54-byte header
   fwrite(header, sizeof(unsigned char), 54, file); 
   fwrite(data, sizeof(struct pixel), size, file); 
   
   fclose(file);
}

// Write the grayscale image to disk.
void write_grayscale_bmp(const char *filename, unsigned char* header, unsigned char* data) 
{
   FILE* file = fopen(filename, "wb");

   // get height and width of image
   int width = (int)(header[19] << 8) | header[18];
   int height = (int)(header[23] << 8) | header[22];
   int size = width * height;
   struct pixel * data_temp = (struct pixel *)malloc(size*sizeof(struct pixel)); 
   
   // write the 54-byte header
   fwrite(header, sizeof(unsigned char), 54, file); 
   int y, x;
   
   // the r field of the pixel has the grayscale value. copy to g and b.
   for (y = 0; y < height; y++) {
      for (x = 0; x < width; x++) {
         (*(data_temp + y*width + x)).b = (*(data + y*width + x));
         (*(data_temp + y*width + x)).g = (*(data + y*width + x));
         (*(data_temp + y*width + x)).r = (*(data + y*width + x));
      }
   }
   
   size = width * height;
   fwrite(data_temp, sizeof(struct pixel), size, file); 
   
   free(data_temp);
   fclose(file);
}

// Determine the grayscale 8 bit value by averaging the r, g, and b channel values.
void convert_to_grayscale(struct pixel * data, int height, int width, unsigned char *grayscale_data) 
{
   for (int i = 0; i < width*height; i++) 
   {
	   grayscale_data[i] = (data[i].r + data[i].g + data[i].b) / 3;
   }
}

void subtract_background(unsigned char *base, unsigned char *img, int height, int width, unsigned char *img_out) 
{
    for (int y = 0; y < height; y++) 
    {
        for (int x = 0; x < width; x++) 
        {
            unsigned char data = (unsigned char)abs(img[y * width + x] - base[y * width + x]);
            img_out[y * width + x] = data > THRESHOLD ? 0xFF : 0x00;
        }
    }
}

void highlight_image(struct pixel * data, unsigned char *img, int height, int width, struct pixel * img_out) 
{
    for (int y = 0; y < height; y++) 
    {
        for (int x = 0; x < width; x++) 
        {
            img_out[y * width + x] = data[y * width + x];
            if ( img[y * width + x] == 0xff )
            {
               img_out[y * width + x].r = 0xff;
               img_out[y * width + x].g = 0x00;
               img_out[y * width + x].b = 0x00;
            }
        }
    }
}


int main(int argc, char *argv[]) 
{
	struct pixel *base_frame = (struct pixel *)malloc(768*576*sizeof(struct pixel));
	struct pixel *img_frame = (struct pixel *)malloc(768*576*sizeof(struct pixel));
	struct pixel *out_frame = (struct pixel *)malloc(768*576*sizeof(struct pixel));
	unsigned char *base_gs = (unsigned char *)malloc(768*576*sizeof(unsigned char));
	unsigned char *img_gs = (unsigned char *)malloc(768*576*sizeof(unsigned char));
	unsigned char *output_img = (unsigned char *)malloc(768*576*sizeof(unsigned char));
	unsigned char header[64];
	int height, width;

	FILE * base_file = fopen("base.bmp","rb");
	if ( base_file == NULL ) return 0;

	FILE * img_file = fopen("pedestrians.bmp","rb");
	if ( img_file == NULL ) return 0;

	// read the bitmap
	read_bmp(base_file, header, &height, &width, base_frame);
	read_bmp(img_file, header, &height, &width, img_frame);

	/// Grayscale conversion
	convert_to_grayscale(base_frame, height, width, base_gs);
	write_grayscale_bmp("base_grayscale.bmp", header, base_gs);

	convert_to_grayscale(img_frame, height, width, img_gs);
	write_grayscale_bmp("img_grayscale.bmp", header, img_gs);

	subtract_background(base_gs, img_gs, height, width, output_img);
	write_grayscale_bmp("img_mask.bmp", header, output_img);

	highlight_image(img_frame, output_img, height, width, out_frame);
	write_bmp("img_out.bmp", header, out_frame);

	return 0;
}


