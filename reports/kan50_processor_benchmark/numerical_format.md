# KAN-50 numerical format

The processor has no floating-point instruction or general multiply instruction, so the representative kernel uses signed 32-bit integer arithmetic derived from frozen FP32 values.

- Conv2 input values are loaded from frozen KAN-350 `pool1.npy` sample 002 and converted as `input_q = round-to-nearest-even(float64(input) * 32)`.
- Conv2 weights are converted as `weight_q = round-to-nearest-even(float64(weight) * 16)`.
- The Conv2 bias is converted at product scale: `bias_q = round-to-nearest-even(float64(bias) * 512)`.
- Each output is `bias_q + sum(input_q * weight_q)` using a signed 32-bit accumulator.
- Weight sign is stored separately; the program repeatedly adds the input magnitude and conditionally subtracts the resulting product for negative weights.
- Two's-complement 32-bit wrap is the defined overflow behaviour. The generated values remain far below the overflow limit.

The independent Python generator computes these integer results directly from the frozen NumPy exports. The processor output is compared with exact integer equality; no CPU-generated values are used as the oracle.

