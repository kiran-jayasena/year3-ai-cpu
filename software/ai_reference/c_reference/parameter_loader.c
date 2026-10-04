#include "parameter_loader.h"

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define PATH_BUFFER_SIZE 1024

static int join_path(char *destination,
                     size_t destination_size,
                     const char *directory,
                     const char *filename) {
    const int written = snprintf(destination, destination_size, "%s/%s", directory, filename);
    return written >= 0 && (size_t)written < destination_size;
}

static int read_exact_file(const char *path, uint8_t *destination, size_t byte_count) {
    FILE *file = fopen(path, "rb");
    int extra_byte;

    if (file == NULL) {
        fprintf(stderr, "Could not open %s for reading.\n", path);
        return 0;
    }
    if (fread(destination, 1, byte_count, file) != byte_count) {
        fprintf(stderr, "File %s is shorter than the expected %zu bytes.\n", path, byte_count);
        fclose(file);
        return 0;
    }
    extra_byte = fgetc(file);
    if (extra_byte != EOF) {
        fprintf(stderr, "File %s is longer than the expected %zu bytes.\n", path, byte_count);
        fclose(file);
        return 0;
    }
    if (fclose(file) != 0) {
        fprintf(stderr, "Could not close %s after reading.\n", path);
        return 0;
    }
    return 1;
}

int load_exact_u8_file(const char *path, uint8_t *destination, size_t element_count) {
    return read_exact_file(path, destination, element_count);
}

int load_f32le_file(const char *path, float *destination, size_t element_count) {
    FILE *file;
    size_t index;

    if (sizeof(float) != 4) {
        fprintf(stderr, "This reference requires 32-bit float.\n");
        return 0;
    }
    file = fopen(path, "rb");
    if (file == NULL) {
        fprintf(stderr, "Could not open %s for reading.\n", path);
        return 0;
    }

    for (index = 0; index < element_count; ++index) {
        uint8_t bytes[4];
        uint32_t bits;

        if (fread(bytes, 1, sizeof(bytes), file) != sizeof(bytes)) {
            fprintf(stderr, "File %s has fewer than %zu FP32 values.\n", path, element_count);
            fclose(file);
            return 0;
        }
        bits = (uint32_t)bytes[0] | ((uint32_t)bytes[1] << 8U) | ((uint32_t)bytes[2] << 16U) |
               ((uint32_t)bytes[3] << 24U);
        memcpy(&destination[index], &bits, sizeof(bits));
    }

    if (fgetc(file) != EOF) {
        fprintf(stderr, "File %s has more than %zu FP32 values.\n", path, element_count);
        fclose(file);
        return 0;
    }
    if (fclose(file) != 0) {
        fprintf(stderr, "Could not close %s after reading.\n", path);
        return 0;
    }
    return 1;
}

int write_f32le_file(const char *path, const float *source, size_t element_count) {
    FILE *file;
    size_t index;

    if (sizeof(float) != 4) {
        fprintf(stderr, "This reference requires 32-bit float.\n");
        return 0;
    }
    file = fopen(path, "wb");
    if (file == NULL) {
        fprintf(stderr, "Could not open %s for writing.\n", path);
        return 0;
    }

    for (index = 0; index < element_count; ++index) {
        uint32_t bits;
        uint8_t bytes[4];

        memcpy(&bits, &source[index], sizeof(bits));
        bytes[0] = (uint8_t)(bits & 0xffU);
        bytes[1] = (uint8_t)((bits >> 8U) & 0xffU);
        bytes[2] = (uint8_t)((bits >> 16U) & 0xffU);
        bytes[3] = (uint8_t)((bits >> 24U) & 0xffU);
        if (fwrite(bytes, 1, sizeof(bytes), file) != sizeof(bytes)) {
            fprintf(stderr, "Could not write FP32 value to %s.\n", path);
            fclose(file);
            return 0;
        }
    }

    if (fclose(file) != 0) {
        fprintf(stderr, "Could not close %s after writing.\n", path);
        return 0;
    }
    return 1;
}

int write_i32le_file(const char *path, int32_t value) {
    const uint32_t bits = (uint32_t)value;
    const uint8_t bytes[4] = {
        (uint8_t)(bits & 0xffU),
        (uint8_t)((bits >> 8U) & 0xffU),
        (uint8_t)((bits >> 16U) & 0xffU),
        (uint8_t)((bits >> 24U) & 0xffU),
    };
    FILE *file = fopen(path, "wb");
    int write_succeeded;

    if (file == NULL) {
        fprintf(stderr, "Could not open %s for writing.\n", path);
        return 0;
    }
    write_succeeded = fwrite(bytes, 1, sizeof(bytes), file) == sizeof(bytes);
    if (fclose(file) != 0) {
        write_succeeded = 0;
    }
    if (!write_succeeded) {
        fprintf(stderr, "Could not write prediction to %s.\n", path);
        return 0;
    }
    return 1;
}

int load_model_parameters(const char *directory, CnnParameters *parameters) {
    char path[PATH_BUFFER_SIZE];

#define LOAD_PARAMETER(field, filename, count)                                                   \
    do {                                                                                          \
        if (!join_path(path, sizeof(path), directory, filename) ||                               \
            !load_f32le_file(path, parameters->field, count)) {                                  \
            return 0;                                                                             \
        }                                                                                         \
    } while (0)

    LOAD_PARAMETER(conv1_weight, "conv1_weight.f32le", CONV1_WEIGHT_ELEMENTS);
    LOAD_PARAMETER(conv1_bias, "conv1_bias.f32le", CONV1_BIAS_ELEMENTS);
    LOAD_PARAMETER(conv2_weight, "conv2_weight.f32le", CONV2_WEIGHT_ELEMENTS);
    LOAD_PARAMETER(conv2_bias, "conv2_bias.f32le", CONV2_BIAS_ELEMENTS);
    LOAD_PARAMETER(fc_weight, "fc_weight.f32le", FC_WEIGHT_ELEMENTS);
    LOAD_PARAMETER(fc_bias, "fc_bias.f32le", FC_BIAS_ELEMENTS);

#undef LOAD_PARAMETER
    return 1;
}
