#include "cnn_reference.h"

_Static_assert(FLATTEN_ELEMENTS == POOL2_ELEMENTS, "Pool2 must flatten to exactly 200 values");
_Static_assert(CONV1_WEIGHT_ELEMENTS + CONV1_BIAS_ELEMENTS + CONV2_WEIGHT_ELEMENTS +
                       CONV2_BIAS_ELEMENTS + FC_WEIGHT_ELEMENTS + FC_BIAS_ELEMENTS ==
                   2346,
               "The frozen model must contain exactly 2,346 parameters");

void preprocess_u8_to_f32(const uint8_t *input, float *output, size_t element_count) {
    size_t index;

    for (index = 0; index < element_count; ++index) {
        output[index] = (float)input[index] / 255.0f;
    }
}

void conv2d_chw(const float *input,
                int input_channels,
                int input_height,
                int input_width,
                const float *weights,
                const float *bias,
                int output_channels,
                int kernel_height,
                int kernel_width,
                float *output) {
    const int output_height = input_height - kernel_height + 1;
    const int output_width = input_width - kernel_width + 1;
    int output_channel;
    int output_y;
    int output_x;
    int input_channel;
    int kernel_y;
    int kernel_x;

    for (output_channel = 0; output_channel < output_channels; ++output_channel) {
        for (output_y = 0; output_y < output_height; ++output_y) {
            for (output_x = 0; output_x < output_width; ++output_x) {
                float accumulator = bias[output_channel];

                for (input_channel = 0; input_channel < input_channels; ++input_channel) {
                    for (kernel_y = 0; kernel_y < kernel_height; ++kernel_y) {
                        for (kernel_x = 0; kernel_x < kernel_width; ++kernel_x) {
                            const int input_index =
                                ((input_channel * input_height + output_y + kernel_y) * input_width) +
                                output_x + kernel_x;
                            const int weight_index =
                                (((output_channel * input_channels + input_channel) * kernel_height +
                                  kernel_y) *
                                 kernel_width) +
                                kernel_x;
                            accumulator += input[input_index] * weights[weight_index];
                        }
                    }
                }

                output[((output_channel * output_height + output_y) * output_width) + output_x] =
                    accumulator;
            }
        }
    }
}

void relu_f32(const float *input, float *output, size_t element_count) {
    size_t index;

    for (index = 0; index < element_count; ++index) {
        const float value = input[index];
        output[index] = value > 0.0f ? value : 0.0f;
    }
}

void maxpool2d_chw(const float *input,
                   int channels,
                   int input_height,
                   int input_width,
                   int pool_height,
                   int pool_width,
                   int stride,
                   float *output) {
    const int output_height = ((input_height - pool_height) / stride) + 1;
    const int output_width = ((input_width - pool_width) / stride) + 1;
    int channel;
    int output_y;
    int output_x;
    int pool_y;
    int pool_x;

    for (channel = 0; channel < channels; ++channel) {
        for (output_y = 0; output_y < output_height; ++output_y) {
            for (output_x = 0; output_x < output_width; ++output_x) {
                const int first_index =
                    ((channel * input_height + output_y * stride) * input_width) + output_x * stride;
                float maximum = input[first_index];

                for (pool_y = 0; pool_y < pool_height; ++pool_y) {
                    for (pool_x = 0; pool_x < pool_width; ++pool_x) {
                        const int input_index =
                            ((channel * input_height + output_y * stride + pool_y) * input_width) +
                            output_x * stride + pool_x;
                        if ((pool_y != 0 || pool_x != 0) && input[input_index] > maximum) {
                            maximum = input[input_index];
                        }
                    }
                }

                output[((channel * output_height + output_y) * output_width) + output_x] = maximum;
            }
        }
    }
}

void flatten_chw(const float *input, float *output, size_t element_count) {
    size_t index;

    for (index = 0; index < element_count; ++index) {
        output[index] = input[index];
    }
}

void fully_connected(const float *input,
                     int input_features,
                     const float *weights,
                     const float *bias,
                     int output_features,
                     float *output) {
    int output_feature;
    int input_feature;

    for (output_feature = 0; output_feature < output_features; ++output_feature) {
        float accumulator = bias[output_feature];

        for (input_feature = 0; input_feature < input_features; ++input_feature) {
            const int weight_index = output_feature * input_features + input_feature;
            accumulator += input[input_feature] * weights[weight_index];
        }

        output[output_feature] = accumulator;
    }
}

int argmax_f32(const float *input, int element_count) {
    int maximum_index = 0;
    float maximum_value = input[0];
    int index;

    for (index = 1; index < element_count; ++index) {
        const float value = input[index];
        if (value > maximum_value) {
            maximum_index = index;
            maximum_value = value;
        }
    }

    return maximum_index;
}

int cnn_run(const uint8_t raw_input[INPUT_HEIGHT * INPUT_WIDTH],
            const CnnParameters *parameters,
            CnnActivations *activations) {
    preprocess_u8_to_f32(raw_input, activations->input, INPUT_ELEMENTS);

    conv2d_chw(activations->input,
               INPUT_CHANNELS,
               INPUT_HEIGHT,
               INPUT_WIDTH,
               parameters->conv1_weight,
               parameters->conv1_bias,
               CONV1_OUT_CHANNELS,
               KERNEL_HEIGHT,
               KERNEL_WIDTH,
               activations->conv1);
    relu_f32(activations->conv1, activations->relu1, CONV1_ELEMENTS);
    maxpool2d_chw(activations->relu1,
                  CONV1_OUT_CHANNELS,
                  CONV1_OUT_HEIGHT,
                  CONV1_OUT_WIDTH,
                  2,
                  2,
                  2,
                  activations->pool1);

    conv2d_chw(activations->pool1,
               CONV1_OUT_CHANNELS,
               POOL1_HEIGHT,
               POOL1_WIDTH,
               parameters->conv2_weight,
               parameters->conv2_bias,
               CONV2_OUT_CHANNELS,
               KERNEL_HEIGHT,
               KERNEL_WIDTH,
               activations->conv2);
    relu_f32(activations->conv2, activations->relu2, CONV2_ELEMENTS);
    maxpool2d_chw(activations->relu2,
                  CONV2_OUT_CHANNELS,
                  CONV2_OUT_HEIGHT,
                  CONV2_OUT_WIDTH,
                  2,
                  2,
                  2,
                  activations->pool2);

    flatten_chw(activations->pool2, activations->flatten, FLATTEN_ELEMENTS);
    fully_connected(activations->flatten,
                    FLATTEN_ELEMENTS,
                    parameters->fc_weight,
                    parameters->fc_bias,
                    OUTPUT_CLASSES,
                    activations->logits);

    return argmax_f32(activations->logits, OUTPUT_CLASSES);
}
