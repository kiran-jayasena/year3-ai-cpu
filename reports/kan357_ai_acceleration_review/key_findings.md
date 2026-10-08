# KAN-357 key findings

## Evidence-backed findings

- The frozen workload is scalar and achieves 26.72 instructions/MAC and 40.67 cycles/MAC at 93 MHz.
- The profile contains 216 conditional branches, 151 jumps, 144 loop-counter updates, 265 ADDI instructions and 216 scalar ADD/SUB instructions.
- 216 control-flush cycles were measured. Zero memory-wait, data-hazard and load-use stalls were measured.
- The 280 residual excess cycles remain unclassified and are not assigned to a mechanism here.
- Existing DOT4ACC/MAC8 hardware is physically present but is not issued by the benchmark.

## Strong candidate mechanisms for comparison

Custom low-precision instructions, packed INT8/SIMD, tightly coupled dot-product execution, loop/control acceleration, and a small convolution engine each have a direct or well-defined hypothesis against the measured profile.

## Conditional mechanisms

Scratchpads and DMA primarily address data movement, reuse, bandwidth or transfer overlap. They may become important for larger workloads or after compute acceleration, but zero memory-wait cycles make them weakly justified as the first S4 intervention. A narrow vector extension is plausible; a complete vector ISA has substantial architectural and software scope.

## Required discipline in KAN-358

Measure total cycles, retired instructions, control flushes, useful MACs, Fmax, LUT/FF/DSP/BRAM, power and energy with the frozen golden output. Separate memory-access instruction count from memory-stall cycles. Include setup/packing/transfer overhead and do not infer a cause for the 280 residual cycles without new evidence.
