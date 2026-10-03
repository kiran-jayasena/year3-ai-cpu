# KAN-349 deterministic desktop CNN reference

## Purpose and scope

This directory contains an independent, reproducible FP32 software reference
for a deliberately small image-classification workload. It does not use or
modify the custom CPU, RTL, accelerator logic, processor instructions, or
Vivado flow.

**The desktop software reference is the independent correctness oracle for
later C/C++, CPU and accelerator implementations.**

KAN-348 is marked complete in Jira, but neither that issue's description or
comments nor the repository records the intended choice between MNIST and
Fashion-MNIST. KAN-349 therefore resolves the missing dataset decision to
**MNIST**, the smaller-risk choice for a first correctness oracle.

## Exact architecture

All tensors are NCHW in PyTorch. Dimensions below omit the batch dimension.

| Stage | Definition | Output shape |
| --- | --- | ---: |
| Input | One 28x28 grayscale image | 1x28x28 |
| Conv1 | 4 filters, 3x3, stride 1, no padding, bias | 4x26x26 |
| ReLU1 | Element-wise ReLU | 4x26x26 |
| Pool1 | 2x2 max pool, stride 2 | 4x13x13 |
| Conv2 | 8 filters, 3x3, stride 1, no padding, bias | 8x11x11 |
| ReLU2 | Element-wise ReLU | 8x11x11 |
| Pool2 | 2x2 max pool, stride 2 | 8x5x5 |
| Flatten | C-row-major PyTorch flatten | 200 |
| FC/logits | 200 inputs to 10 outputs, with bias | 10 |

Parameter count: Conv1 40 + Conv2 296 + FC 2,010 = **2,346**.
This is 9,384 bytes at FP32. A simple all-parameter INT8 estimate is 2,346
bytes; an eventual quantised design may choose wider biases and will document
that separately.

The model performs approximately **61,184 MACs per inference**:

- Conv1: `4 * 26 * 26 * 1 * 3 * 3 = 24,336`
- Conv2: `8 * 11 * 11 * 4 * 3 * 3 = 34,848`
- FC: `10 * 200 = 2,000`

Convolution MACs are output channels times output height times output width
times input channels times kernel height times kernel width. FC MACs are inputs
times outputs. Bias additions, ReLU, max comparisons and pooling are excluded.
The largest activation is Conv1/ReLU1: 2,704 FP32 values, or 10,816 bytes.

## Dataset, preprocessing, and fixed samples

The official MNIST training and test IDX files are downloaded from the PyTorch
dataset mirror and checked against the canonical MNIST MD5 values. Each uint8
pixel is converted to FP32 and divided by 255.0. There is no resize, data
augmentation, mean subtraction, or standard-deviation normalization.

The fixed random seed is **349** for Python, NumPy, and PyTorch. Training and
inference use CPU only, one PyTorch thread, deterministic algorithms, no data
loader workers, and disabled MKLDNN. The fixed test indices, ordered by class
0 through 9, are:

`[3, 2, 1, 30, 4, 8, 11, 0, 61, 7]`

## Environment and commands

The frozen evidence was produced with Python 3.14.0, PyTorch 2.14.1, and NumPy
2.5.3. From this directory on Windows PowerShell:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt

# Only needed once to create a checkpoint. Refuses to overwrite by default.
.\.venv\Scripts\python.exe train_reference.py

# Reloads the checkpoint; it never trains.
.\.venv\Scripts\python.exe generate_golden.py

# Performs two fresh generations and checks every generated file by SHA-256.
.\.venv\Scripts\python.exe verify_golden.py
```

The checkpoint is `artifacts/small_cnn_reference.pt`; its SHA-256 is
`9216dc089e92c480214db348c80bd6e1237ac14ff2a665345b228123be47759c`.
It is also recorded in `artifacts/small_cnn_reference.pt.sha256` and in the results files. Golden
inputs, labels, stage outputs, logits, predictions and their hash manifest are
under `golden/`. Parameter `.npy` files and raw FP32 C-array conversion inputs
are under `exports/`. Environment, training, statistics, and reproducibility
evidence are under `results/`.

## Expected output

Training prints three epoch summaries, model statistics, final test accuracy,
and the checkpoint hash. Golden generation prints all ten index/label/prediction
records and model statistics. Verification must finish with `status: PASS`,
`byte_identical: true`, and `canonical_matches_regeneration: true`.

Exact measured accuracy, predictions, checkpoint hash, and aggregate golden
hash are preserved in `results/results_summary.md`.
