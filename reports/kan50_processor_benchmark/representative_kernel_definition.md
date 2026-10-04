# KAN-50 representative kernel definition

## Source and scope

This benchmark is derived from the frozen KAN-349/KAN-350 MNIST CNN Conv2 layer. It selects output channel 0, input channel 0, and the 2x2 output tile at `(y,x) = (0,0), (0,1), (1,0), (1,1)`. Each output uses the same 3x3 kernel and its overlapping 4x4 input region from the frozen KAN-350 `pool1` tensor for sample 002.

The selected computation is therefore four independent Conv2 outputs with:

`4 outputs * 3 * 3 products = 36 MAC-equivalent products`.

It preserves the Conv2 CHW input indexing, OIHW weight indexing, 3x3 valid-convolution structure, overlapping spatial windows, per-output bias, and signed accumulation. The subset is bounded because the unchanged CPU has 256-word instruction and data memories.

## Processor mapping

The generated program uses only `ADDI`, `ADD`, `SUB`, `LOAD`, `STORE`, `BEQ`, and `JUMP`. It loops over four outputs and nine products per output. Each product loads a quantised input, weight magnitude, and sign, then performs software repeated addition. Negative weights select subtraction. No MAC8, DOT4ACC, multiply instruction, or hardware acceleration is used.

The final output store at byte address 452 is the sentinel used by the KAN-51 instrumentation convention.

## Source files

- Generated program: `programs/kan50_conv2_tile.mem`
- Generated data image: `programs/kan50_conv2_tile_data.mem`
- Independent integer golden: `programs/kan50_conv2_tile_golden.mem`
- Generator: `software/ai_reference/tools/generate_kan50_conv2_tile.py`

