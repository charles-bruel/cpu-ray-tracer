#include "main.h"

#define WIDTH 160
#define HEIGHT 120
#define NUM_CHANNELS 3
#define BITS_P_PIXEL NUM_CHANNELS * 8
#define HEADER_SIZE 14
#define DIB_HEADER_SIZE 40 //(BITMAPINFOHEADER)

int main() {
    scene scene = create_test_scene();

    color *data = malloc(WIDTH * HEIGHT * sizeof(color));
    int temp = generate(data, WIDTH, HEIGHT, &scene);
    printf("%d\n", temp);
    char *converted_array = convert_for_writing(data, WIDTH, HEIGHT, 1);
    write_file(converted_array, WIDTH, HEIGHT);
    free(converted_array);
    free(data);

    return 0;
}

scene create_test_scene() {
    unsigned int size = sizeof(camera);
    camera *camera = malloc(size);
    (*camera).pos = vec(0, 0, 0);
    (*camera).view_dir = vec(1, 0, 0);
    (*camera).fov = 70.0f * 0.0174533f;
    scene scene;
    scene.camera = camera;
    scene.ambient = col(0.7f, 0.9f, 1.0f);
    scene.ambient_strength = 0.1f;
    scene.num_spheres = 1;
    scene.spheres = malloc(1 * sizeof(vec3));
    scene.spheres[0] = vec(5, 0, 0);
    
    return scene;
}

void write_file(char *data, unsigned int width, unsigned int height) {
    //God forgive me for what I have written

    unsigned int size = 0;
    size += HEADER_SIZE;
    size += DIB_HEADER_SIZE;
    unsigned int row_size = 4 * ((BITS_P_PIXEL * width + 31) / 32);
    size += row_size * height;
    char *buffer = malloc(size);

    unsigned int total_header_size = HEADER_SIZE + DIB_HEADER_SIZE;
    unsigned int dib_header_size = DIB_HEADER_SIZE;
    unsigned short color_planes = 1;
    unsigned short bits_per_pixel = BITS_P_PIXEL;
    unsigned int zero = 0;

    memset(buffer, 0, total_header_size);//Zero by default
                                         //Empty values below are zeroes

    //Regular header
    memcpy(buffer + 0 , "BM"                , 2);//Identifier
    memcpy(buffer + 2 , &size               , 4);//File size
                                                 //Reserved x2
    memcpy(buffer + 10, &total_header_size  , 4);//Start data offset

    //DIB header
    memcpy(buffer + 14, &dib_header_size    , 4);//Header size
    memcpy(buffer + 18, &width              , 4);//Image width
    memcpy(buffer + 22, &height             , 4);//Image height
    memcpy(buffer + 26, &color_planes       , 2);//Color planes
    memcpy(buffer + 28, &bits_per_pixel     , 2);//Bits per pixel
                                                 //Compression method. 0 means none (BI_RGB)
                                                 //Image size (can be dummy 0 for BI_RGB)
                                                 //Horizontal resolution (pixels per meter)
                                                 //Vertical resolution (pixels per meter)
                                                 //Number of colors in palette
                                                 //Number of important colors

    char *image_data = buffer + total_header_size;

    unsigned int row_size_og = width * NUM_CHANNELS;
    for(int i = 0;i < height;i ++) {
        memcpy(image_data + row_size * i, data + row_size_og * i, row_size_og);
    }
    
    FILE *write_ptr = fopen("..\\out\\img.bmp", "wb");//https://stackoverflow.com/questions/17598572/read-and-write-to-binary-files-in-c
    fwrite(buffer, 1, size, write_ptr);
    fclose(write_ptr);
    free(buffer);
}

char *convert_for_writing(color *array, unsigned int width, unsigned int height, float max_value) {
    char *to_return = malloc(width * height * NUM_CHANNELS * sizeof(char));

    for(int i = 0;i < width;i ++) {
        for(int j = 0;j < height;j ++) {
            int index = j * width + i;
            float r = 255 * array[index].r / max_value;
            float g = 255 * array[index].g / max_value;
            float b = 255 * array[index].b / max_value;
            if(r > 255) r = 255;
            if(g > 255) g = 255;
            if(b > 255) b = 255;
            if(r <   0) r =   0;
            if(g <   0) g =   0;
            if(b <   0) b =   0;
            char rf = (char) r;
            char bf = (char) b;
            char gf = (char) g;
            to_return[index * 3 + 2] = rf;
            to_return[index * 3 + 1] = gf;
            to_return[index * 3 + 0] = bf;
        }
    }

    return to_return;
}

vec3 vec(float x, float y, float z) {
    vec3 to_return;
    to_return.x = x;
    to_return.y = y;
    to_return.z = z;
    return to_return;
}

color col(float r, float g, float b) {
    color to_return;
    to_return.r = r;
    to_return.g = g;
    to_return.b = b;
    return to_return;
}

// void generate(color *array, unsigned int width, unsigned int height) {
//     for(int i = 0;i < width;i ++) {
//         for(int j = 0;j < height;j ++) {
//             int index = j * width + i;
//             array[index].r = (float) j / width;
//             array[index].g = 0;
//             array[index].b = (float) i / width;
//         }
//     }
// }