# Baseline CNN Workload Profile

**Purpose:** establish a reproducible scalar CNN-style baseline before implementing Variant A.  
**Baseline identity:** `fyp-stage3-baseline` / `f6b25ca196493858cc2b501a0324c4a794c0dd94`  
**Stage 4 evidence freeze:** `fyp-stage4-evidence-freeze` / `020c3279e1b9770c4c361dd8ea0fe769b2e4fcaf`  
**Profile date:** 2026-10-10

## A. Baseline architecture summary

The measured design is `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2`, wrapped by `fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2`. It is a 32-bit in-order pipelined soft CPU with BRAM-backed instruction and data memories, a 32-entry register file with two read ports, a scalar ALU, forwarding/hazard control, branch/jump redirect logic, and retirement/performance outputs.

The ISA uses 32-bit instructions with a 4-bit opcode, 5-bit `rd`, `rs1`, `rs2`, and 13-bit signed immediate. The relevant instructions are `ADDI`, `ADD`, `SUB`, `LOAD`, `STORE`, `BEQ` and `JUMP`. The repository also defines `MAC8` and `DOT4ACC`; the selected baseline core contains those AI datapaths, including a four-lane pipelined DOT4ACC unit, but the benchmark deliberately does not issue either instruction.

Instruction and data memories are 32-bit word memories indexed by `addr[31:2]`. The benchmark therefore has word-aligned loads/stores and no cache or external-memory interface. Existing counters expose total cycles, retired instructions, pipeline fill, data-hazard stalls, load-use stalls, control flushes, instruction-fetch waits, memory waits, branch direction, jumps and wrong-path flushes. Retirement also exposes opcode, PC and store information, which is sufficient for an observational trace without changing RTL.

The frozen FPGA implementation is a Basys 3 `xc7a35tcpg236-1` design at a repeatably timing-clean 93.000 MHz point.

## B. Benchmark definition

The simplest useful CNN-style kernel already present is the Conv2-derived quantised 2×2 output tile in `programs/kan50_conv2_tile.mem`. It computes four output values, each from a 3×3 product set: 36 useful MAC-equivalent products in total. The data and independent golden output are:

```text
programs/kan50_conv2_tile_data.mem
programs/kan50_conv2_tile_golden.mem
golden output = [-116, 15, -97, 90]
```

The software implementation uses repeated signed addition/subtraction rather than a multiply instruction. It loads operands and bias values, builds each product using the available scalar arithmetic, accumulates each output, and stores four outputs plus a sentinel store used by the testbench to delimit the run. This is an intentionally fair baseline: it measures what the frozen scalar software actually does, while leaving the physically present MAC/DOT hardware unused.

No new benchmark program was required. The existing KAN-58 program is the representative workload, and the KAN-62 profiling testbench adapts it for measurement by observing retirement and existing counters only.

## C. Measurement table

| Metric | Result | Classification / source |
|---|---:|---|
| Useful MAC-equivalent operations | 36 | Measured workload definition |
| Total execution cycles | 1,464 | Existing KAN-58/KAN-62 profile |
| Retired instructions | 962 | Retirement counter and trace |
| CPI | 1.5218295 | `1464 / 962` |
| ADD instructions | 204 | Opcode trace |
| SUB instructions | 12 | Opcode trace |
| Scalar arithmetic/accumulation | 216 | ADD + SUB |
| LOAD operations | 109 | Opcode trace |
| STORE operations | 5 | Four outputs plus sentinel |
| Conditional branches | 216 | BEQ opcode count |
| Unconditional jumps | 151 | JUMP opcode count |
| Address/loop/setup ADDI | 265 | 112 address + 144 loop + 9 setup |
| Control-flush cycles | 216 | Direct counter |
| Pipeline-fill cycles | 6 | Direct counter |
| Data-hazard stalls | 0 | Direct counter |
| Load-use stalls | 0 | Direct counter |
| Instruction-fetch waits | 0 | Direct counter |
| Memory-wait cycles | 0 | Direct counter |
| Wrong-path instructions flushed | 281 | Direct counter |
| Dynamic data bytes moved | 456 bytes | `(109 + 5) × 4`; includes sentinel store |
| Arithmetic intensity | 0.07895 MAC/byte | `36 / 456`; dynamic CPU data traffic convention |
| Execution time at 93 MHz | 15.741935 µs | `1464 / 93,000,000` |
| Output | `[-116, 15, -97, 90]` | Exact golden match |

The byte count is explicitly a dynamic CPU data-memory convention: every retired 32-bit load/store contributes four bytes, and instruction-fetch traffic is excluded. If the sentinel store is excluded, the comparison traffic is 452 bytes and intensity is 0.07965 MAC/byte. Neither number is a claim about unique tensor bytes or external DRAM traffic.

### Approximate cycle attribution

The existing counters do not provide a non-overlapping arithmetic-cycle or memory-cycle partition. The defensible attribution is therefore two-layered:

| View | Arithmetic | Memory | Control | Other / unresolved |
|---|---:|---:|---:|---:|
| Retired-instruction proxy | 22.45% (216) | 11.85% (114) | 38.15% (367) | 27.55% ADDI (265) |
| Direct cycle evidence | Not isolated | 0% measured waits | 14.75% flushes (216) | 65.71% one-cycle retirement reference; 0.41% fill; 19.13% residual |

The instruction proxy is useful for workload composition, not a measured cycle partition. The direct cycle evidence supports control overhead and rejects memory waiting as the dominant explanation. The 280 residual excess cycles remain unclassified.

## D. Bottleneck analysis

### Observed facts

- The workload retires 26.72 instructions/MAC and takes 40.67 cycles/MAC.
- 216 scalar ADD/SUB instructions represent the 36 products, or six arithmetic instructions per MAC-equivalent operation on average.
- 367 branch/jump instructions and 216 measured control-flush cycles show substantial control overhead.
- 265 ADDI instructions perform address generation, loop-counter updates and setup.
- 114 load/store instructions are significant instruction traffic, but the memory-wait counter is zero.
- Data-hazard, load-use and instruction-fetch wait counters are zero.
- 280 excess cycles are not assigned to a known cause.

### Conclusion

The evidence-supported dominant bottleneck is scalar instruction-count and control-flow overhead, with significant address/loop bookkeeping and scalar arithmetic. Memory access is an instruction-count component, not a measured memory-latency bottleneck. A faster arithmetic unit alone may therefore leave important branch, address and loop cost in place.

### What is not established

The profile does not prove that arithmetic consumes 22.45% of cycles, because arithmetic-cycle attribution is not exposed. It does not prove that the 280 residual cycles are memory, hazards or a single hidden pipeline effect. It also does not show a workload-derived Fmax limitation; the physical baseline is timing-clean at 93 MHz.

## E. Estimated optimisation headroom

These are analytical upper-bound estimates, not measurements. They assume the indicated instructions can issue without new stalls, timing loss or added setup cost, and that all non-target instructions retain their current cost.

| Candidate change | Simplified assumption | Optimistic cycles | Speed-up ceiling from this model |
|---|---|---:|---:|
| One custom scalar MAC per product | Replace six ADD/SUB instructions per product with 36 MAC instructions | 1,284 | 1.14× |
| Four-lane DOT4ACC-style instruction | Replace 216 ADD/SUB instructions with 9 four-product instructions | 1,257 | 1.16× |
| Four parallel MAC lanes, same scalar control | Reduce arithmetic issue count from 216 to about 54 | 1,302 | 1.12× |
| Remove all current load/store issue cost | Idealised removal of 114 memory instructions, no replacement cost | 1,350 | 1.08× |
| Standalone scratchpad, current workload | No measured wait to remove | approximately 1,464 | approximately 1.00× |

The first three estimates are deliberately modest because they retain all 367 control transfers and all address/loop overhead. A tightly coupled engine that also absorbs operand loads, address generation and loop control could exceed these instruction-only estimates, but that is a different interface hypothesis and must include launch, completion, packing and verification costs. A banked scratchpad can make parallel MAC delivery feasible, but it has no demonstrated standalone cycle benefit in S4.

## F. Recommended initial Variant A parameters

The recommended starting configuration for later implementation work is provisional, not a final architecture decision:

- **Four signed INT8 MAC lanes.** This matches the existing DOT4ACC four-lane arithmetic concept and is large enough to test meaningful parallelism while remaining close to the current five-DSP baseline and the Basys 3 resource envelope.
- **Two 32-bit scratchpad banks.** Use one bank for packed activations and one for packed weights/operands, with the interface designed to provide one operand word from each bank per accelerator issue. This tests banked delivery without immediately adding four or eight independent BRAM ports.
- **A lightweight start/busy/done interface.** Keep the first experiment bounded to a command that supplies source addresses, output/accumulator destination and element count, with explicit completion and no DMA.
- **No DMA or double buffering in the first Variant A.** The current workload has zero memory-wait cycles and only 36 MAC-equivalent operations. DMA should be revisited only after a larger tile or a faster compute engine produces measured transfer/compute overlap potential.

This recommendation is based on the evidence that arithmetic and control instructions are expensive while memory latency is not observed. KAN-358 should compare four lanes against smaller/larger alternatives and measure whether the two-bank interface actually sustains operand delivery. It should not assume the parameters are optimal.

## G. Exact files used or changed

No RTL, ISA, program, data, memory, constraint, or frozen evidence file was changed for this analysis. The existing reproducible measurement assets are:

- `programs/kan50_conv2_tile.mem` — scalar benchmark instruction image.
- `programs/kan50_conv2_tile_data.mem` — benchmark data image.
- `programs/kan50_conv2_tile_golden.mem` — expected four-word output.
- `reports/kan62_baseline_bottleneck_profile/tb_kan62_profile.sv` — observational profiling testbench.
- `reports/kan62_baseline_bottleneck_profile/run_profile.ps1` — Vivado XSim compile/elaborate/run script.
- `reports/kan62_baseline_bottleneck_profile/execution_trace.txt` — retained retirement trace.
- `reports/kan62_baseline_bottleneck_profile/opcode_counts.csv` — mutually exclusive instruction counts.
- `reports/kan62_baseline_bottleneck_profile/cycle_breakdown.csv` — measured and residual cycle accounting.
- `reports/kan55_baseline_fpga_implementation/run_result.csv` — post-route resource/timing point.
- `reports/kan56_timing_baseline/timing_summary.json` — repeatability and highest clean frequency.

The new analysis artifacts are this report and `measurement_table.csv`. No accelerator implementation has begun.

## H. Next implementation step

Before writing Variant A RTL, use the frozen scalar trace to define an interface-level golden model for four-lane signed INT8 MAC execution and a two-bank operand-access model. Then implement the smallest isolated MAC unit and self-checking testbench, followed by a CPU-facing integration experiment in a copied RTL path. Preserve the scalar program and the 1,464-cycle result as the comparison baseline. Add DMA only if a larger workload or the integrated accelerator produces measured data-transfer exposure.
