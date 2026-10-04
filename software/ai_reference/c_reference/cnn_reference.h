#ifndef CNN_REFERENCE_H
#define CNN_REFERENCE_H

#include <stddef.h>
#include <stdint.h>

#define INPUT_CHANNELS 1
#define INPUT_HEIGHT 28
#define INPUT_WIDTH 28
#define INPUT_ELEMENTS (INPUT_CHANNELS * INPUT_HEIGHT * INPUT_WIDTH)

#define CONV1_OUT_CHANNELS 4
#define CONV1_OUT_HEIGHT 26
#define CONV1_OUT_WIDTH 26
#define CONV1_ELEMENTS (CONV1_OUT_CHANNELS * CONV1_OUT_HEIGHT * CONV1_OUT_WIDTH)

#define POOL1_HEIGHT 13
#define POOL1_WIDTH 13
#define POOL1_ELEMENTS (CONV1_OUT_CHANNELS * POOL1_HEIGHT * POOL1_WIDTH)

#define CONV2_OUT_CHANNELS 8
#define CONV2_OUT_HEIGHT 11
#define CONV2_OUT_WIDTH 11
#define CONV2_ELEMENTS (CONV2_OUT_CHANNELS * CONV2_OUT_HEIGHT * CONV2_OUT_WIDTH)

#define POOL2_HEIGHT 5
#define POOL2_WIDTH 5
#define POOL2_ELEMENTS (CONV2_OUT_CHANNELS * POOL2_HEIGHT * POOL2_WIDTH)

#define FLATTEN_ELEMENTS 200
#define OUTPUT_CLASSES 10
#define KERNEL_HEIGHT 3
#define KERNEL_WIDTH 3

#define CONV1_WEIGHT_ELEMENTS (CONV1_OUT_CHANNELS * INPUT_CHANNELS * KERNEL_HEIGHT * KERNEL_WIDTH)
#define CONV1_BIAS_ELEMENTS CONV1_OUT_CHANNELS
#define CONV2_WEIGHT_ELEMENTS (CONV2_OUT_CHANNELS * CONV1_OUT_CHANNELS * KERNEL_HEIGHT * KERNEL_WIDTH)
#define CONV2_BIAS_ELEMENTS CONV2_OUT_CHANNELS
#define FC_WEIGHT_ELEMENTS (OUTPUT_CLASSES * FLATTEN_ELEMENTS)
#define FC_BIAS_ELEMENTS OUTPUT_CLASSES

typedef struct {
    float conv1_weight[CONV1_WEIGHT_ELEMENTS];
    float conv1_bias[CONV1_BIAS_ELEMENTS];
    float conv2_weight[CONV2_WEIGHT_ELEMENTS];
    float conv2_bias[CONV2_BIAS_ELEMENTS];
    float fc_weight[FC_WEIGHT_ELEMENTS];
    float fc_bias[FC_BIAS_ELEMENTS];
} CnnParameters;

typedef struct {
    float input[INPUT_ELEMENTS];
    float conv1[CONV1_ELEMENTS];
    float relu1[CONV1_ELEMENTS];
    float pool1[POOL1_ELEMENTS];
    float conv2[CONV2_ELEMENTS];
    float relu2[CONV2_ELEMENTS];
    float pool2[POOL2_ELEMENTS];
    float flatten[FLATTEN_ELEMENTS];
    float logits[OUTPUT_CLASSES];
} CnnActivations;

void preprocess_u8_to_f32(const uint8_t *input, float *output, size_t element_count);

void conv2d_chw(const float *input,
                int input_channels,
                int input_height,
                int input_width,
                const float *weights,
                const float *bias,
                int output_channels,
                int kernel_height,
                int kernel_width,
                float *output);

void relu_f32(const float *input, float *output, size_t element_count);

void maxpool2d_chw(const float *input,
                   int channels,
                   int input_height,
                   int input_width,
                   int pool_height,
                   int pool_width,
                   int stride,
                   float *output);

void flatten_chw(const float *input, float *output, size_t element_count);

void fully_connected(const float *input,
                     int input_features,
                     const float *weights,
                     const float *bias,
                     int output_features,
                     float *output);

int argmax_f32(const float *input, int element_count);

int cnn_run(const uint8_t raw_input[INPUT_HEIGHT * INPUT_WIDTH],
            const CnnParameters *parameters,
            CnnActivations *activations);

#endif
