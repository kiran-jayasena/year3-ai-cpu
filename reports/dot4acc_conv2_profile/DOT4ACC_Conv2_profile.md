# DOT4ACC/MAC Measurement Against the Frozen Conv2 Baseline

## A. Existing MAC8/DOT4ACC architecture and instruction semantics

This measurement uses the existing `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2` path. No RTL, ISA, frozen scalar program, or baseline evidence was changed.

The common instruction format is `[31:28] opcode, [27:23] rd, [22:18] rs1, [17:13] rs2, [12:0] imm13`. `OP_MAC8 = 4'hb` and `OP_DOT4ACC = 4'hc`; the active core accepts DOT4ACC only with a canonical zero immediate.

* MAC8 computes `rd = rd + signed8(rs1[7:0]) * signed8(rs2[7:0])`. The product is a full signed 16-bit product, sign-extended to 32 bits, then added modulo 2^32. `rd` is both accumulator input and destination. Writes to x0 are suppressed.
* DOT4ACC computes four signed INT8 products from byte lanes `[7:0]`, `[15:8]`, `[23:16]`, and `[31:24]` of each source, sums them, sign-extends the result, and adds it to the accumulator in `rd`, modulo 2^32. It has no saturation or overflow flag. The lane order is little-endian within each packed word.
* The DOT datapath uses four inferred multiplier DSPs, with non-DSP reduction and accumulation logic. Its RTL pipeline is three enabled rising edges from accepted input to raw result and has initiation interval one; the core adds private metadata, completion, forwarding, and retirement handling. The frozen implementation reports five DSP48E1 sites overall: four DOT multipliers and the existing MAC8 multiply path.
* MAC8 follows the normal pipeline: its result is formed from the ID/EX operands in the EX arithmetic path, can forward through EX/MEM and MEM/WB, and retires through the normal writeback path at one result per enabled pipeline opportunity unless a dependency stalls it. DOT4ACC uses a private issue/completion path. Same-register DOT chains are supported when contiguous; the core carries the prior completed result into the next accumulation. A DOT chain must not be interrupted by a non-DOT instruction.
* Synchronous BRAM reads have one-cycle read latency. The exact benchmark therefore uses conservative software spacing between operand loads. This is a scheduling requirement of the existing path, not a new hardware change.

These statements were checked against `docs/isa.md`, `rtl/cpu_defs_pkg.sv`, `rtl/dot4acc_pipeline.sv`, the active core, and existing DOT reference/benchmark testbenches. MAC8 was not used for the exact Conv2 run because the workload naturally provides four packed INT8 lanes per DOT4ACC instruction; no byte-extraction instruction exists to cheaply form equivalent packed MAC8 operands.

## B. Mapping of Conv2 onto the specialised instruction

The frozen workload has four outputs, nine products per output, and bias -119. The additive data image stores 12 packed activation words and 12 packed effective-weight words. Each output uses three DOT4ACC operations, so the complete kernel uses 12 DOT4ACC instructions for 48 lane slots, of which 36 lanes are the mathematical MAC-equivalent operations; the remaining 12 lanes are zero-valued padding.

For each output, the program loads three activation/weight word pairs, waits between synchronous loads, issues three contiguous DOT4ACC instructions into one accumulator register, and stores the result. Four accumulator registers are used. Setup uses six ADDI instructions. There are no branches, jumps, pointer-update loops, or scalar ADD/SUB instructions in this specialised program. It still has 24 loads and five stores: 116 bytes of dynamic data traffic under the same four-byte-per-memory-instruction accounting used for the scalar report.

## C. Functional verification

The XSim harness `tb_dot4acc_conv2_profile.sv` ran the new program with the same mathematical inputs and checks the four output words before accepting the run.

| Output | Expected | Measured | Result |
|---|---:|---:|---|
| 0 | -116 | -116 | pass |
| 1 | 15 | 15 | pass |
| 2 | -97 | -97 | pass |
| 3 | 90 | 90 | pass |

The run retired exactly 12 DOT4ACC instructions and zero MAC8 instructions. Signed negative lanes and the 32-bit modular accumulator behaviour are exercised by the effective-weight packing and the negative bias. No overflow or saturation discrepancy was observed.

## D. Scalar vs specialised profiling table

The scalar column is the frozen S4/KAN-62 evidence. The specialised column is the new XSim trace. “ADDI/control/setup” is the ADDI opcode count; NOPs are not included in that label.

| Metric | Scalar baseline | DOT4ACC/MAC version | Change |
|---|---:|---:|---:|
| Cycles | 1464 | 232 | -1232 (-84.15%) |
| Retired instructions | 962 | 207 | -755 (-78.48%) |
| CPI | 1.5218295 | 1.1207729 | -0.4010566 |
| Loads | 109 | 24 | -85 (-77.98%) |
| Stores | 5 | 5 | 0 |
| Branches | 216 | 0 | -216 (-100%) |
| Jumps | 151 | 0 | -151 (-100%) |
| ADDI/control/setup | 265 | 6 | -259 (-97.74%) |
| Scalar arithmetic | 216 | 0 | -216 (-100%) |
| DOT4ACC/MAC instructions | 0 | 12 DOT4ACC, 0 MAC8 | +12 specialised |
| Memory-wait cycles | 0 | 0 | 0 |
| Data-hazard stalls | 0 | 0 | 0 |
| Load-use stalls | 0 | 0 | 0 |
| Control-flush cycles | 216 | 0 | -216 |
| Dynamic bytes moved | 456 | 116 | -340 (-74.56%) |
| MAC-equivalent operations | 36 | 36 | 0 |
| Cycles/MAC-equivalent | 40.6667 | 6.4444 | -84.15% |
| MAC-equivalent operations/cycle | 0.024590 | 0.155172 | 6.31x |

The specialised run also reports six pipeline-fill cycles and 20 instruction-fetch-wait cycles. The run has 25 cycles beyond its 207 retired instructions; these counter categories are not a disjoint cycle partition, so six plus 20 must not be treated as an exact decomposition.

Because the specialised benchmark changes only program/data images and the simulation harness, the applicable FPGA resource/timing baseline remains 2,008 LUTs, 1,812 FFs, five DSP48E1, one BRAM tile (two RAMB18), and timing-clean operation at 93 MHz. No new synthesis result is claimed.

## E. Speed-up and instruction-count analysis

Measured cycle speed-up is `1464/232 = 6.31x`. Retired instructions fall by 78.48%, and the arithmetic/control instruction classes that dominated the scalar trace disappear from the kernel. The specialised program is not a one-instruction idealisation: it retains 24 operand loads, five stores, six setup ADDIs, 160 NOPs used for safe instruction/data timing, and the DOT issue/retirement pipeline effects.

The reduction is higher than the earlier analytical estimates of 1.14x for scalar MAC, 1.16x for four-lane DOT4ACC, and 1.12x for four parallel MACs without control reduction. Those estimates were conservative thought experiments that retained much of the scalar loop/control schedule and did not model replacing the four nine-iteration loops with a fully unrolled, branch-free packed program. The measured result therefore combines compute compression with loop/control elimination and reduced data traffic. It must not be interpreted as the isolated gain of a future accelerator over an equally optimised packed software schedule.

## F. Explanation of previously unclassified cycles

For the scalar run, `1464 - 962 = 502` cycles are not retired-instruction cycles. Subtracting the 216 reported control-flush cycles leaves approximately 286 cycles, commonly rounded to the previously reported 280 residual/unclassified cycles after accounting for reporting conventions. The exact residual is not a causal category: retirement, flush, fill, fetch, and stall counters are updated on different pipeline events and can overlap or omit bubbles.

The active core counts pipeline fill while no instruction has retired, control flush on redirect events, fetch wait on `frontend_stall`, and memory/data hazard counters on `decode_stall`. It does not expose a disjoint “every cycle” attribution. The frozen scalar evidence reports zero memory waits, data-hazard stalls, load-use stalls, and fetch waits, but that does not prove every non-retired cycle was arithmetic or control work. Plausible contributors are synchronous instruction fetch response/fill and drain, redirect handling beyond the single counted event, pipeline retirement timing, and benchmark startup/termination. A precise causal split would require an additive per-cycle stage-valid/hold reason trace; this task does not alter the core to add it.

The specialised run provides a useful comparison: no redirects occur, no memory waits occur, and only 25 cycles exceed retired instructions. Its 20 fetch-wait count confirms that instruction-delivery effects remain visible even after control flow is removed. The evidence supports saying that the scalar residual is approximate and counter categories are not a partition, not assigning all 280 cycles to a single mechanism.

## G. New bottleneck analysis

Strong measured evidence:

* Arithmetic instruction count and branch/control overhead collapse to zero scalar arithmetic, zero branches, zero jumps, and zero control-flush cycles.
* Memory-wait, data-hazard, and load-use stall counters remain zero. The 24 loads are instruction/data traffic, not measured waiting.
* The specialised run is dominated by the instruction schedule: 160 NOPs are required by the current load/operand timing and safe DOT-chain sequencing, while 24 loads and 12 DOT instructions remain.
* Instruction-fetch wait remains 20 cycles. This is the most visible measured non-compute overhead in the specialised run, although the counter is not a complete attribution of all 25 excess cycles.

Packing/data preparation is real software overhead: the packed data image is precomputed, and the runtime program does not pack bytes dynamically. A deployment that receives unpacked activations/weights would pay additional preparation cost. Memory bandwidth is not shown to be limiting: memory wait is zero and no local-memory starvation is measured. Consequently, banked scratchpad memory is not justified by this tiny workload on current evidence.

## H. Recommendation for Variant A

The next experiment should improve or fuse the existing DOT4ACC operand-delivery/control path, or quantify a lightweight zero-overhead loop/control mechanism around it. This targets the measured residual issue/fetch/setup schedule, not a presumed memory bottleneck. It should first be evaluated with the same exact Conv2 workload and a cycle-level trace of fetch/ID/EX/DOT valid and hold reasons.

A new scratchpad, banked scratchpad, DMA engine, or additional parallel MAC array is not yet supported by this measurement: all memory-wait counters are zero, and the current four-lane DOT datapath already delivers a large workload-level gain. A future parallel-MAC experiment remains valuable only if it specifies whether it also removes the 160-NOP/operand-delivery schedule; otherwise its benefit will be masked by instruction issue and control overhead.

This is a recommendation for the next measurement, not a final architecture selection. Likely implementation cost is lower for a software-visible control/issue improvement than for a new memory subsystem; any RTL change must be checked for Fmax, DSP use, and exact output equivalence.

## I. Files changed and why

* `programs/kan50_conv2_tile_dot4acc_data.mem` — additive packed activation/effective-weight image derived from the frozen scalar data.
* `programs/kan50_conv2_tile_dot4acc_scheduled.mem` — additive branch-free DOT4ACC version of the same four-output Conv2 workload.
* `reports/dot4acc_conv2_profile/tb_dot4acc_conv2_profile.sv` — self-checking XSim harness, retirement/opcode counters, output check, and trace generation.
* `reports/dot4acc_conv2_profile/run_profile.ps1` — reproducible Vivado XSim compile/run script.
* `reports/dot4acc_conv2_profile/trace_summary.csv` and `execution_trace.txt` — generated measured evidence.
* `reports/dot4acc_conv2_profile/DOT4ACC_Conv2_profile.md` — this report.
* `reports/dot4acc_conv2_profile/acceleration_comparison.csv` — machine-readable comparison table.

No RTL, ISA definition, scalar program, workload mathematics, frozen report, or FPGA baseline evidence was modified. The existing unrelated untracked baseline-report directory was preserved.

## J. Exact next step

Add a non-invasive cycle reason trace or equivalent simulation-only instrumentation to distinguish fetch response, pipeline hold, DOT issue, and retirement bubbles. Then compare (a) current DOT4ACC, (b) the same DOT4ACC with reduced operand-load spacing if safely supported, and (c) a loop/control-reduced form under the same input/output checks. Only after that comparison should KAN-358 decide whether a DOT/control improvement or a more parallel execution structure merits RTL work.

## Sources inspected

This is a repository-grounded architecture measurement, not a new external literature review. Six primary repository sources were used: `docs/isa.md`, `rtl/cpu_defs_pkg.sv`, `rtl/dot4acc_pipeline.sv`, `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`, `tb/dot4acc_reference.sv`, and `tb/tb_dot4acc_stage_h13b_timingopt_t2_benchmark.sv`. The frozen scalar numbers come from the existing KAN-62 profile and Stage 4 evidence.
