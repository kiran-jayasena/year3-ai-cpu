# KAN-350 scalar C inference mapping

## Purpose and scope

This directory maps the exact frozen KAN-349 MNIST CNN to readable scalar C11.
It loads the unmodified KAN-349 parameters, preprocesses the same fixed uint8
images, executes every layer with explicit loops, and exports each intermediate
tensor for comparison with the independent PyTorch golden reference.

**This C/C++ implementation is a transparent software mapping of the frozen
KAN-349 reference and is not yet a hardware-optimised implementation.**

No CPU RTL, instruction set, testbench, Vivado file, accelerator, custom
instruction, SIMD operation, vectorisation, DMA mechanism, scratchpad, model
parameter, golden tensor, or checkpoint is changed or introduced here. INT8
mapping is future work; this baseline is FP32 only.

## Frozen model and data sources

- Architecture: `1x28x28 -> Conv(1->4, 3x3) -> ReLU -> MaxPool(2x2) ->
  Conv(4->8, 3x3) -> ReLU -> MaxPool(2x2) -> Flatten(200) -> FC(200->10)`.
- Raw inputs and golden tensors: `../golden/sample_000` through `sample_009`.
- Frozen raw parameters: `../exports/c_arrays_source/*.f32le`.
- Parameter manifest: `../exports/parameters_manifest.json`.
- Frozen checkpoint SHA-256:
  `9216dc089e92c480214db348c80bd6e1237ac14ff2a665345b228123be47759c`.

The C program uses no ML, image, linear-algebra, or tensor library. NumPy is
used only by the external Python comparison harness to read the existing
KAN-349 `.npy` oracle files.

## Tensor and parameter layouts

Activations use contiguous CHW order. For `[C][H][W]`, the flat index is
`(c * H + y) * W + x`. Convolution weights use OIHW order and the flat index
`((output_channel * input_channels + input_channel) * kernel_height + ky) *
kernel_width + kx`. Fully connected weights use `[output][input]` order.
Flatten copies the complete `8x5x5` CHW tensor in C-row-major order.

All parameter and generated activation files used by C are headerless
little-endian IEEE-754 FP32 streams. The raw input is exactly 784 uint8 values.
The C loader checks exact file lengths and translates little-endian bit
patterns explicitly.

| Stage | Output dimensions | Elements | Type |
| --- | ---: | ---: | --- |
| Raw input | 28x28 | 784 | uint8 |
| Preprocessed input | 1x28x28 | 784 | FP32 |
| Conv1 / ReLU1 | 4x26x26 | 2,704 | FP32 |
| Pool1 | 4x13x13 | 676 | FP32 |
| Conv2 / ReLU2 | 8x11x11 | 968 | FP32 |
| Pool2 | 8x5x5 | 200 | FP32 |
| Flatten | 200 | 200 | FP32 |
| FC/logits | 10 | 10 | FP32 |
| Prediction | scalar | 1 | signed 32-bit integer |

Preprocessing performs `float(raw_pixel) / 255.0f`. Both convolutions use
stride 1, no padding and a bias. Both pools use a 2x2 window, stride 2 and
floor output sizing. Consequently, Pool2 does not consume the final row and
column of each 11x11 input channel. Argmax uses a strict greater-than test, so
a tie selects the lowest class index, matching PyTorch's first-maximum rule.

## Build, run, and verification

From `software/ai_reference` on Windows PowerShell:

Prerequisites are Python with the parent `requirements.txt` installed and a
GCC/MinGW C compiler available on `PATH`.

```powershell
.\.venv\Scripts\python.exe tools\compare_c_reference.py --clean
```

The harness:

1. performs a clean GCC C11 build with `-O0` and `-ffp-contract=off`;
2. converts only each frozen `raw_input_uint8.npy` into a temporary raw input;
3. runs scalar C inference for all ten fixed samples;
4. reads all C-generated stages;
5. compares every stage and prediction with KAN-349; and
6. writes `results/comparison_results.json` and `.md`.

Temporary inputs, outputs, object/executable files are confined to the ignored
`build/` directory. To run the executable directly after building:

```powershell
.\c_reference\build\cnn_reference.exe `
  .\exports\c_arrays_source `
  .\c_reference\build\inputs\sample_000.u8 `
  .\c_reference\build\outputs\sample_000
```

The comparison rule is finite output and
`max(abs(C_output - KAN-349_output)) <= 1e-5` for every tensor. This is an
absolute FP32 tolerance, chosen before measurement to allow only small
accumulation-rounding differences. Prediction equality is exact. Final
measured errors are recorded in `results/comparison_results.md`.

## Loop, arithmetic, and source-level memory-access structure

Counts below describe explicit source-array element accesses in the scalar
loops. An accumulator local is not counted as an array access. Compiler,
cache, memory-system, and later processor behavior are deliberately not
inferred from these counts.

| Operation | Principal loop nesting | MACs | Approx. array reads | Output writes | Other control/arithmetic |
| --- | --- | ---: | ---: | ---: | --- |
| Preprocess | pixel | 0 | 784 raw | 784 | 784 conversions/divisions |
| Conv1 | output channel, y, x, input channel, ky, kx | 24,336 | 24,336 input + 24,336 weight + 2,704 bias = 51,376 | 2,704 | loop bounds, index arithmetic |
| ReLU1 | element | 0 | 2,704 | 2,704 | 2,704 comparisons |
| Pool1 | channel, output y, output x, ky, kx | 0 | 2,704 | 676 | 2,028 max comparisons |
| Conv2 | output channel, y, x, input channel, ky, kx | 34,848 | 34,848 input + 34,848 weight + 968 bias = 70,664 | 968 | loop bounds, index arithmetic |
| ReLU2 | element | 0 | 968 | 968 | 968 comparisons |
| Pool2 | channel, output y, output x, ky, kx | 0 | 800 | 200 | 600 max comparisons |
| Flatten | element | 0 | 200 | 200 | index increment |
| FC | output feature, input feature | 2,000 | 2,000 input + 2,000 weight + 10 bias = 4,010 | 10 | loop bounds, index arithmetic |
| Argmax | class | 0 | 10 | 1 scalar result | 9 comparisons |

MAC derivation:

- Conv1: `4 output channels * 26 * 26 outputs/channel * 1 input channel * 3 * 3 = 24,336`.
- Conv2: `8 output channels * 11 * 11 outputs/channel * 4 input channels * 3 * 3 = 34,848`.
- FC: `10 outputs * 200 inputs = 2,000`.
- Total: `24,336 + 34,848 + 2,000 = 61,184 MACs`.

Conv2 contains the largest arithmetic workload. The overlapping convolution
windows repeatedly access input activations, each convolution weight is reused
across spatial output positions, and input activations are also reused across
output channels. Pool layers read each used 2x2 value once in this loop order.
The FC layer reuses every one of its 200 input values across ten outputs while
each FC weight is used once per inference. ReLU and flatten are linear
read/write passes. These are visible data-reuse opportunities, not claims
about which resource or operation is a processor bottleneck; that requires
later measurement and profiling.

For transparent verification, `CnnActivations` retains every intermediate
array concurrently: 9,214 FP32 values (36,856 bytes), plus the 784-byte raw
input and 9,384 bytes of parameters. No buffer-reuse optimisation is applied.
