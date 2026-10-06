# KAN-62 Baseline Bottleneck Profile

## Baseline and workload

- Baseline: `fyp-stage3-baseline` → `f6b25ca196493858cc2b501a0324c4a794c0dd94`
- CPU/top: `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2` / `fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2`
- FPGA: `xc7a35tcpg236-1` / Basys 3
- Workload: KAN-58 Conv2-derived quantised tile, MNIST sample 2, output/input channel 0, 2×2 output tile
- Useful work: 4 outputs × 9 products = **36 MAC-equivalent operations**
- Golden output: `[-116, 15, -97, 90]` (exact match)
- Validated frequency context: 93.000 MHz from KAN-56

## Measured execution

| Quantity | Value |
|---|---:|
| Retired instructions | 962 |
| Total cycles | 1,464 |
| CPI | 1.5218295 |
| Excess cycles | 502 |
| Instructions/MAC | 26.7222222 |
| Cycles/MAC | 40.6666667 |
| MACs/cycle | 0.02459016 |

The 962/1,464 values and output were reproduced by the profiling testbench. KAN-50 independently recorded five identical runs.

## Instruction mix

| Category | Count | % retired | Instructions/MAC | Notes |
|---|---:|---:|---:|---|
| Arithmetic/accumulation | 216 | 22.453% | 6.000 | ADD/SUB |
| Loads | 109 | 11.331% | 3.028 | input/weight/bias reads |
| Stores | 5 | 0.520% | 0.139 | four outputs plus sentinel |
| Address generation | 112 | 11.642% | 3.111 | pointer/index ADDIs |
| Loop-counter updates | 144 | 14.969% | 4.000 | loop ADDIs |
| Immediate setup/constants | 9 | 0.936% | 0.250 | setup ADDIs |
| Conditional branches | 216 | 22.453% | 6.000 | 65 taken, 151 not taken |
| Unconditional jumps | 151 | 15.696% | 4.194 | loop/control transfers |
| Other | 0 | 0.000% | 0.000 | — |

Opcode details are in `opcode_counts.csv`; the full retire trace is in `execution_trace.txt`.

## Existing counter and cycle evidence

| Component | Count | % total cycles | Evidence |
|---|---:|---:|---|
| Ideal one-cycle-per-retired reference | 962 | 65.710% | analytical reference |
| Pipeline fill | 6 | 0.410% | existing `pipeline_fill_cycles` counter |
| Control-hazard flush | 216 | 14.754% | existing `control_hazard_flush_cycles` counter |
| Residual excess | 280 | 19.126% | calculated residual, unclassified |

Existing counters also reported: data-hazard stalls `0`, load-use stalls `0`, instruction-fetch waits `0`, memory waits `0`, taken branches `65`, not-taken branches `151`, jumps `151`, wrong-path instructions flushed `281`. The residual is not assigned to memory or hazards without direct evidence.

## Bottleneck classification

| Candidate bottleneck | Classification | Evidence | Confidence |
|---|---|---|---|
| Scalar instruction-count overhead | Dominant | 962 instructions for 36 MACs; 26.72 instructions/MAC | High |
| Branch/control overhead | Dominant | 367 BEQ/JUMP instructions; 216 flush cycles; 281 wrong-path instructions | High |
| Address generation/loop bookkeeping | Significant | 265 ADDI instructions, including 112 address and 144 loop updates | High |
| Arithmetic throughput | Significant | 216 scalar ADD/SUB instructions; products use repeated addition/subtraction | Medium |
| Memory/data movement | Significant instruction component, no measured wait | 114 loads/stores, but memory-wait counter is zero | Medium |
| Pipeline hazards | Not supported by evidence | data-hazard and load-use counters both zero | High |
| Fmax/timing | Not supported by evidence | stable 93 MHz physical point; no workload timing limit measured | Medium |

## Why 36 MACs require 1,464 cycles

The workload's 36 products are represented by a scalar instruction stream rather than a multiply or dot-product instruction. The stream retires 216 ADD/SUB arithmetic instructions, 109 loads, 5 stores, 265 immediate/address/loop ADDIs, and 367 control-transfer instructions. Thus the useful arithmetic is surrounded by substantial data movement, pointer/counter maintenance, loop tests, jumps, and control redirects. The measured 216 redirect-flush cycles and 6-cycle pipeline fill account for 222 of the 502 cycles above the one-cycle-per-retirement reference; the remaining 280 cycles are unclassified by existing counters. This supports a combined instruction/control-flow overhead conclusion, not a claim that all residual cycles have a single cause.

## Candidate S5 directions (not a selection)

| Observed evidence | Plausible response | Why it could help | Evidence strength |
|---|---|---|---|
| High scalar arithmetic instruction count | Custom MAC/dot-product instruction | Replace repeated scalar product/accumulate sequence | Medium |
| 114 loads/stores and repeated data access | Scratchpad/local buffering | Reduce instruction-level data movement if reuse is confirmed | Medium/low; no memory waits measured |
| Repeated transfer/loop movement | DMA/double buffering | Could reduce software transfer overhead in a larger workload | Low for this tile; not directly measured |
| Scalar parallelism opportunity | SIMD/vector extension | Perform multiple independent products per instruction | Medium |
| Convolution product structure | Tightly coupled MAC/convolution engine | Map repeated 3×3 products to dedicated datapath | Medium |

Final accelerator architecture selection is deferred to S5.

## Limitations and conclusion

The trace and counters are simulation-only observations and do not alter architectural behaviour. The existing instrumentation does not expose a complete non-overlapping stall taxonomy; therefore 280 excess cycles remain unclassified. No workload-derived Fmax limitation was measured. The dominant evidence-supported explanation is the combination of scalar instruction-count overhead and branch/control-flow overhead, with significant address/loop bookkeeping and scalar arithmetic. No RTL, ISA, memory, timing constraint, workload, or accelerator optimisation was performed.

