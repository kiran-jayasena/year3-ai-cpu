#ifndef PARAMETER_LOADER_H
#define PARAMETER_LOADER_H

#include "cnn_reference.h"

#include <stddef.h>
#include <stdint.h>

int load_exact_u8_file(const char *path, uint8_t *destination, size_t element_count);
int load_f32le_file(const char *path, float *destination, size_t element_count);
int write_f32le_file(const char *path, const float *source, size_t element_count);
int write_i32le_file(const char *path, int32_t value);
int load_model_parameters(const char *directory, CnnParameters *parameters);

#endif
