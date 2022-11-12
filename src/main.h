#pragma once

#include <stdio.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>

typedef struct {
    float r;
    float g;
    float b;
} color;

char *convert_for_writing(color *array, unsigned int width, unsigned int height, float max_value);
void write_file(char *data, unsigned int width, unsigned int height);
void generate(color *array, unsigned int width, unsigned int height);