#include "cnn_reference.h"
#include "parameter_loader.h"

#include <stdint.h>
#include <stdio.h>

#define PATH_BUFFER_SIZE 1024

typedef struct {
    const char *name;
    const float *values;
    size_t element_count;
} OutputTensor;

static int write_output_tensor(const char *directory, const OutputTensor *tensor) {
    char path[PATH_BUFFER_SIZE];
    const int written = snprintf(path, sizeof(path), "%s/%s.f32le", directory, tensor->name);

    if (written < 0 || (size_t)written >= sizeof(path)) {
        fprintf(stderr, "Output path is too long for %s.\n", tensor->name);
        return 0;
    }
    return write_f32le_file(path, tensor->values, tensor->element_count);
}

int main(int argc, char **argv) {
    CnnParameters parameters;
    CnnActivations activations;
    uint8_t raw_input[INPUT_HEIGHT * INPUT_WIDTH];
    int prediction;
    int prediction_path_length;
    char prediction_path[PATH_BUFFER_SIZE];
    size_t index;
    const OutputTensor outputs[] = {
        {"input", activations.input, INPUT_ELEMENTS},
        {"conv1", activations.conv1, CONV1_ELEMENTS},
        {"relu1", activations.relu1, CONV1_ELEMENTS},
        {"pool1", activations.pool1, POOL1_ELEMENTS},
        {"conv2", activations.conv2, CONV2_ELEMENTS},
        {"relu2", activations.relu2, CONV2_ELEMENTS},
        {"pool2", activations.pool2, POOL2_ELEMENTS},
        {"flatten", activations.flatten, FLATTEN_ELEMENTS},
        {"logits", activations.logits, OUTPUT_CLASSES},
    };

    if (argc != 4) {
        fprintf(stderr, "Usage: %s PARAMETER_DIRECTORY RAW_UINT8_INPUT OUTPUT_DIRECTORY\n", argv[0]);
        return 2;
    }
    if (!load_model_parameters(argv[1], &parameters)) {
        return 3;
    }
    if (!load_exact_u8_file(argv[2], raw_input, sizeof(raw_input))) {
        return 4;
    }

    prediction = cnn_run(raw_input, &parameters, &activations);
    for (index = 0; index < sizeof(outputs) / sizeof(outputs[0]); ++index) {
        if (!write_output_tensor(argv[3], &outputs[index])) {
            return 5;
        }
    }

    prediction_path_length =
        snprintf(prediction_path, sizeof(prediction_path), "%s/predicted_class.i32le", argv[3]);
    if (prediction_path_length < 0 || (size_t)prediction_path_length >= sizeof(prediction_path) ||
        !write_i32le_file(prediction_path, (int32_t)prediction)) {
        return 6;
    }

    printf("predicted_class=%d\n", prediction);
    return 0;
}
