# KAN-350 C reference comparison results

Overall result: **PASS**

Absolute FP32 tolerance: `1.0e-05`

## Maximum absolute error across all ten samples

| Stage | Shape | Maximum absolute error | Result |
| --- | --- | ---: | --- |
| input | 1x28x28 | 0 | PASS |
| conv1 | 4x26x26 | 2.38418579e-07 | PASS |
| relu1 | 4x26x26 | 2.38418579e-07 | PASS |
| pool1 | 4x13x13 | 2.38418579e-07 | PASS |
| conv2 | 8x11x11 | 2.86102295e-06 | PASS |
| relu2 | 8x11x11 | 2.86102295e-06 | PASS |
| pool2 | 8x5x5 | 2.86102295e-06 | PASS |
| flatten | 200 | 2.86102295e-06 | PASS |
| logits | 10 | 7.62939453e-06 | PASS |

## Per-sample predictions

| Sample | Dataset index | Ground truth | Expected | C result | Layers | Prediction |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| sample_000 | 3 | 0 | 0 | 0 | PASS | PASS |
| sample_001 | 2 | 1 | 1 | 1 | PASS | PASS |
| sample_002 | 1 | 2 | 2 | 2 | PASS | PASS |
| sample_003 | 30 | 3 | 3 | 3 | PASS | PASS |
| sample_004 | 4 | 4 | 4 | 4 | PASS | PASS |
| sample_005 | 8 | 5 | 5 | 5 | PASS | PASS |
| sample_006 | 11 | 6 | 6 | 6 | PASS | PASS |
| sample_007 | 0 | 7 | 7 | 7 | PASS | PASS |
| sample_008 | 61 | 8 | 8 | 8 | PASS | PASS |
| sample_009 | 7 | 9 | 9 | 9 | PASS | PASS |

The comparison used the unmodified KAN-349 golden `.npy` tensors and raw parameter exports.
