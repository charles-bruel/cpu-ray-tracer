#pragma once

#include <stdio.h>
#include <math.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

#pragma pack(1)
typedef struct {
    float r;
    float g;
    float b;
} color;

typedef struct {
    float x, y, z;//0, 4, 8
} vec3;

typedef struct {
    vec3 pos;//0-12
    float r;//12-16
    unsigned int material_id;//16-20
} sphere;

typedef struct {
    vec3 pos1;
    vec3 pos2;
    vec3 pos3;
} triangle;

typedef struct {
    vec3 pos;//0-12
    vec3 view_dir;//12-24
    float fov;//24-28
} camera;

typedef struct {
    color color;
    float emission;
    float roughness;
} material;

typedef struct {
    sphere *spheres;//0-8
    triangle *tris;//8-16
    material *materials;//16-24
    unsigned int num_materials;//24-28
    float ambient_strength;//28-32
    unsigned int num_spheres;//32-36
    unsigned int num_tris;//36-40
    camera *camera;//40-48
    color ambient;//48-60
} scene;

scene create_test_scene();
char *convert_for_writing(color *array, unsigned int width, unsigned int height, float max_value);
void write_file(char *data, unsigned int width, unsigned int height);
extern int generate(color *array, unsigned int width, unsigned int height, scene *scene);
vec3 vec(float x, float y, float z);
color col(float r, float g, float b);
triangle tri(vec3 pos1, vec3 pos2, vec3 pos3);
sphere sph(vec3 pos, float r, unsigned int material_id);
material mat(color color, float emission, float roughness);
// void generate(color *array, unsigned int width, unsigned int height);