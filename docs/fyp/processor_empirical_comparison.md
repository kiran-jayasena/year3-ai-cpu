# Bounded Cross-Processor Empirical Comparison

## A. Objective

This experiment tests whether the frozen custom scalar CPU is an unusually weak
baseline for the Year III AI-acceleration investigation. It compares the custom
CPU scalar ISA with a realistic scalar PicoRV32 configuration and attempts a
MicroBlaze V run only if the existing Vivado/IP/compiler flow is available
without disproportionate integration work.

The experiment is deliberately bounded. It does not add an accelerator, modify
the custom CPU, port the full CNN, or claim that DOT4ACC is faster than either
external processor.

## B. Execution status

The benchmark assets and preflight validation were executed. RTL simulation,
PicoRV32 execution, MicroBlaze V execution and new synthesis were not executed
because the required tools are unavailable in the current environment.

| Activity | Status | Evidence |
|---|---|---|
| Revised plan saved | PASS | `experiments/processor_empirical_comparison/README.md` |
| N=16 vectors/golden generated | PASS | `experiments/processor_empirical_comparison/n16/` |
| N=128 vectors/golden generated | PASS | `experiments/processor_empirical_comparison/n128/` |
| Custom programs generated | PASS | 164 instruction words for N=16; 26 for N=128 |
| Exact asset preflight | PASS | `preflight_results.csv` |
| Custom CPU XSim run | BLOCKED | `xvlog`, `xelab`, `xsim` unavailable |
| PicoRV32 run | BLOCKED | RTL/toolchain/simulator flow unavailable |
| MicroBlaze V run | BLOCKED | Vivado/IP/compiler flow unavailable |
| New resource/timing builds | BLOCKED | Vivado unavailable |
| Protected baseline RTL changed | NO | Read-only audit and Git status |
| Historical benchmark evidence changed | NO | Read-only audit and Git status |

The block is a real technical blocker under the approved stop rule, not an
estimated performance result. No empirical cycle, Fmax or resource value has
been invented.

## C. Benchmark specification

The operation is:

```text
sum = Σ(a[i] × b[i]), i = 0 .. N-1
```

Arithmetic rules:

* operands are signed int8;
* the accumulator is signed 32-bit modulo 2^32;
* the operation count is exactly N MACs;
* the output is one 32-bit result word;
* code and data are local/on-chip where practical;
* no OS, libraries, peripheral I/O, interrupts, DMA or accelerator are used;
* a run is valid only if its output exactly matches the stored golden value.

### N=16 validation case

The required deterministic vectors are:

```text
a = [ 3, -2,  5, -4,  7, -1,  2, -6,
      4, -3,  1, -5,  6, -7,  0,  8 ]

b = [-3,  4, -1, -2,  2, -5,  6,  3,
     -4,  7, -8,  1, -2,  5,  9, -1 ]
```

The derived result is `-106`, represented as `0xFFFFFF96`.

### N=128 primary case

The generated deterministic vectors are stored in
`experiments/processor_empirical_comparison/n128/vectors.csv`.

The generator uses:

```text
a[i] = ((17i + 3) mod 8) + 1
b[i] = (((29i + 5) mod 8) + 1) × (+1 if i even, -1 if i odd)
```

All values are valid signed-int8 values. The exact result is `576`, represented
as `0x00000240`. The canonical word images, golden output and metadata are
stored under the N=128 experiment directory.

N=512 was not added because the required simulator/compiler flow was already
blocked and extending the benchmark would not produce empirical evidence.

## D. Fairness assumptions

The intended common settings are:

| Setting | Intended value | Actual status |
|---|---|---|
| FPGA | `xc7a35tcpg236-1` | Not built |
| Vivado | 2026.1 | Not available |
| Reference clock | 93 MHz | Not measured for new runs |
| Memory | local BRAM/simple on-chip memory | Encoded in plan, not run |
| Cache | disabled | Not configured because external runs blocked |
| Compiler | exact version recorded | No RISC-V/MicroBlaze compiler available |
| Optimisation | `-O2` primary | Not compiled |
| Measurement | deterministic start/done or cycle counter | Not executed |

Any future successful run must preserve these settings or record the deviation.
Cycle results must be kept separate from execution-time results when clock
frequency is not measured.

## E. Custom CPU scalar result

The protected core is:

```text
rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv
```

The generated scalar programs use only ADD, SUB, ADDI, LOAD, STORE, BEQ and
JUMP. MAC8 and DOT4ACC are not issued.

The N=16 program is 164 words and performs fixed-data signed multiplication by
repeated ADD/SUB operations. The N=128 program is 26 words. To fit the frozen
256-word data memory while retaining a loop, its physical data image stores
positive magnitudes for A and B; the generated loop applies the alternating
canonical B sign. The canonical signed vectors remain the correctness oracle.
This representation difference is documented rather than hidden.

### Empirical metrics

No custom scalar cycle run was possible because XSim and alternative simulators
are unavailable. Therefore the following are unavailable, not zero:

| Metric | N=16 | N=128 |
|---|---:|---:|
| Total cycles | unavailable | unavailable |
| Retired instructions | unavailable | unavailable |
| Cycles/MAC | unavailable | unavailable |
| Instructions/MAC | unavailable | unavailable |
| Loads/stores | unavailable | unavailable |
| Branches/jumps | unavailable | unavailable |
| Control flushes | unavailable | unavailable |
| Fetch waits | unavailable | unavailable |
| Memory waits | unavailable | unavailable |
| Data-hazard stalls | unavailable | unavailable |
| Load-use stalls | unavailable | unavailable |
| Exact result | not executed | not executed |

The generated testbench is ready to collect these values from the existing
retirement and performance-counter ports:

`experiments/processor_empirical_comparison/tb_custom_scalar_comparison.sv`

## F. Custom scalar instruction/cycle breakdown

The following are static/analytical counts from the generated programs, not
RTL measurements.

### N=16

The absolute B magnitudes sum to 63. The unrolled multiplication-emulation
arithmetic therefore contains 63 repeated ADD/SUB instructions. The program
also contains 32 operand loads, 64 pointer/setup instructions around the
iterations, 16 accumulator updates, one final store and control-free padding.
Dynamic retired counts, cycles and percentages remain unavailable until XSim
runs.

### N=128

The positive B magnitudes sum to 576. For each product, the generated loop
contains one final condition check plus four instructions per repeated addition:

```text
BEQ + ADD + ADDI + JUMP
```

Derived multiplication-emulation cost is therefore:

| Quantity | Derived value |
|---|---:|
| MACs | 128 |
| Repeated additions | 576 |
| Inner-loop instructions including checks/jumps | 2,432 |
| Including per-product zero/setup instructions | 2,688 |
| Canonical golden result | `0x00000240` |

These counts show why the custom scalar ISA is expected to be disadvantaged on
this benchmark, but they do not show how many clock cycles the pipeline spends
on the emulation. In particular, the existing counters are not a disjoint
cycle partition, so multiplication-emulation cycles must not be inferred by
subtracting instruction counts from total cycles.

## G. PicoRV32 result

PicoRV32 execution was not attempted beyond the feasibility preflight. The
planned primary configuration remains:

* dual-port register file;
* counters enabled;
* no PCPI accelerator;
* hardware multiply enabled;
* native valid/ready memory interface;
* local deterministic memory;
* no cache;
* `-O2` compiled benchmark;
* N=16 validation followed by N=128 performance measurement.

Optional no-multiply and fast-multiply variants were not attempted.

The blocker is environmental: PicoRV32 RTL is not present in the repository,
and no RISC-V GCC, simulator or Vivado flow is available on PATH. Downloading
and integrating the RTL without a compiler/simulator would not produce a valid
empirical comparison, so this branch was stopped under the approved rule.

The intended source reference remains the [PicoRV32 repository and README](https://github.com/YosysHQ/picorv32).

## H. MicroBlaze V result

MicroBlaze V was not attempted beyond feasibility preflight. The planned
configuration remains a 32-bit area-oriented scalar core with caches disabled,
local BRAM, divider disabled, no custom instructions and the normal realistic
hardware multiplier.

The blocker is stronger than a missing benchmark source: Vivado, XSim and the
MicroBlaze compiler/IP flow were not found on PATH or under the checked
`C:\FPGA` installation area. Building BSP, AXI, linker and debug infrastructure
from this state would violate the bounded-task rule.

MicroBlaze V therefore remains an architectural reference only for this
experiment. The planned external reference is based on the [AMD MicroBlaze V
Processor Reference Guide](https://docs.amd.com/r/en-US/ug1629-microblaze-v-user-guide).

## I. Same-CPU scalar/MAC8/DOT4ACC comparison

The inherited same-CPU results are preserved and are not merged with the new
N=128 vectors unless the vectors are identical.

| Comparison | Cycles | Status |
|---|---:|---|
| Inherited Conv2 scalar | 1,464 | Measured historical result |
| Inherited Conv2 DOT4ACC | 232 | Measured historical result |
| Inherited common 128-product MAC8 | 134 | Measured historical result |
| Inherited common 128-product DOT4ACC | 43 | Measured historical result |
| New N=128 scalar | unavailable | Tool-blocked |
| New N=128 MAC8 | not run | Tool-blocked |
| New N=128 DOT4ACC | not run | Tool-blocked |

The inherited common 128-product result gives:

```text
134 / 43 = 3.116x
```

This is the stronger controlled AI-acceleration comparison because it holds CPU,
memory system, clock, instruction encoding family, verification harness and
implementation constant. It is not a cross-processor scalar result.

## J. Cross-processor scalar comparison

No empirical cycle table can be populated without fabricating results. The
current evidence table is therefore:

| Processor/configuration | N=16 | N=128 | Correctness | Cycle status |
|---|---:|---:|---|---|
| Custom scalar software-multiply | not executed | not executed | Assets validated; RTL run blocked | unavailable |
| PicoRV32 with hardware MUL | not executed | not executed | Not tested | unavailable |
| MicroBlaze V with normal MUL | not executed | not executed | Not tested | unavailable |

The benchmark specification and data are ready, but the comparison is not an
empirical processor-performance result.

## K. Resource/timing comparison

No new synthesis was performed. The only directly measured custom baseline
remains the inherited result:

| Design | Device/tool | LUT | FF | DSP | BRAM | Frequency |
|---|---|---:|---:|---:|---:|---:|
| Custom H1.3b-T2 | Basys 3 `xc7a35tcpg236-1`, Vivado 2026.1 | 2,008 | 1,812 | 5 | 2 RAMB18 | 93 MHz clean |
| PicoRV32 | not built | unavailable | unavailable | unavailable | unavailable | unavailable |
| MicroBlaze V | not built | unavailable | unavailable | unavailable | unavailable | unavailable |

No cross-processor resource conclusion is supported by this execution.

## L. Baseline-fairness analysis

### 1. Is the custom scalar CPU unusually weak?

The design is weak as a general-purpose scalar ISA, but this execution did not
produce the requested empirical cross-processor cycle evidence. The conclusion
must therefore remain qualified rather than stronger than the data.

The architectural reason for weakness is clear: the custom scalar ISA has no
general multiply, shifts or byte extraction. The N=128 generated benchmark
requires 2,688 derived multiplication-loop instructions before pipeline effects
are counted. PicoRV32 and MicroBlaze V can normally use scalar hardware
multiplication, so a future successful comparison would be expected to show a
substantial arithmetic advantage for them.

### 2. How much is due to missing multiply?

The generated instruction accounting strongly indicates that missing multiply
is a major source of work: 576 repeated additions plus loop checks, decrements
and jumps are required for 128 products. However, there is no measured cycle
breakdown yet. It is not defensible to claim that all scalar excess cycles are
caused by multiplication.

### 3. Is the pipeline/memory architecture otherwise credible?

Yes, based on inherited repository evidence rather than this blocked experiment.
The custom CPU has a multi-boundary in-order pipeline, forwarding, load-use
handling, branch flushing, synchronous BRAM memories and explicit profiling
counters. Its Conv2 profile reports zero memory-wait, data-hazard, load-use and
fetch-wait cycles. That supports a credible local-memory datapath, while leaving
the residual cycles and control overhead to be analysed carefully.

### 4. Are fetch waits or memory waits the main issue?

The inherited Conv2 evidence says no: both memory-wait and fetch-wait counters
are zero. The new N=16/N=128 runs could not independently confirm this because
simulation was unavailable.

### 5. Would a normal lightweight scalar processor likely be faster?

Architecturally, likely yes when hardware multiplication is enabled. MicroBlaze
V and PicoRV32 have richer standard scalar instruction support and established
toolchains. This remains an informed architectural inference, not a new measured
claim in this execution.

## M. Platform recommendation

The empirical comparison did not weaken the existing recommendation to retain
the custom CPU. It also did not prove that the custom scalar baseline is fair in
the sense of matching a standard RV32IM-class processor.

The defensible position is:

* scalar custom-CPU speed-up is a platform-specific result and is partly exposed
  to baseline weakness;
* MAC8 versus DOT4ACC is the stronger controlled specialised-AI result;
* the custom CPU remains valid for Year III because its RTL, pipeline, counters,
  verification and modification path are directly accessible;
* MicroBlaze V and PicoRV32 should remain external architectural references until
  their flows can be run under controlled conditions.

## N. Implications for Variant A

The comparison does not change the current Year III direction. Variant A should
not be justified solely by the 6.31x scalar-to-DOT4ACC Conv2 result. It should
measure improvement against both:

1. the frozen scalar custom-ISA baseline; and
2. the inherited accelerated controls, especially MAC8 and DOT4ACC where the
   workload is mathematically identical.

The next bottleneck remains scalar instruction/control overhead rather than
measured memory latency. Variant A must therefore expose launch, operand
delivery, packing, address generation, completion and control cost, and must not
assume that more MAC lanes alone will remove the observed overhead.

## O. Limitations

* No new RTL simulation was possible.
* No PicoRV32 empirical result was possible.
* No MicroBlaze V empirical result was possible.
* No new synthesis, Fmax or resource comparison was possible.
* Custom multiplication counts are derived from generated program structure,
  not measured retirement traces.
* The N=128 custom memory image uses magnitudes plus a generated sign schedule
  to express signed multiplication on the frozen ISA; the canonical signed
  vectors remain the common correctness definition.
* The inherited custom Conv2 and 128-product results use existing benchmark
  definitions and must not be conflated with the new N=128 dataset.

## P. Suggested final-report wording

“A bounded cross-processor benchmark was specified using deterministic signed-
int8 dot products at N=16 and N=128. The benchmark assets, exact goldens and
custom scalar programs were generated and validated, but execution of XSim,
PicoRV32 and MicroBlaze V was blocked because the required simulator, Vivado/IP
and compiler tools were unavailable in the measurement environment. No
cross-processor cycle or resource values were fabricated. Analytical accounting
of the custom N=128 program requires 2,688 multiplication-loop instructions for
128 products because the custom scalar ISA lacks general multiply. This supports
the conclusion that the scalar baseline is weaker than a normal RV32IM-class
soft processor, but does not establish a cycle-level causal breakdown. The
custom CPU remains a credible Year III implementation platform because its RTL,
pipeline, counters, verification flow and custom-acceleration path are fully
inspectable. Performance claims should therefore report both the platform-
specific scalar-to-DOT4ACC result and the stronger same-CPU MAC8-to-DOT4ACC
control, measured as 134 versus 43 cycles or approximately 3.116x.”

## Q. Jira-ready summary

**Status:** Bounded comparison assets complete; empirical processor execution
blocked by unavailable tools.

**Completed:** Revised plan; deterministic N=16 and N=128 signed-int8 vectors;
goldens `0xFFFFFF96` and `0x00000240`; custom scalar programs; preflight
validation; static software-multiply accounting; blocker documentation.

**Not completed:** Custom XSim runs, PicoRV32 runs, MicroBlaze V runs and new
synthesis/resource measurements.

**Decision:** Retain the custom CPU as the Year III implementation platform.
Treat scalar-to-DOT4ACC as a custom-ISA/platform-specific result. Use the
existing MAC8-to-DOT4ACC 3.116x comparison as the stronger controlled AI
acceleration result. Keep MicroBlaze V and PicoRV32 as architectural references
until a tool-complete environment is available.

**Next action:** Run the prepared experiment in a Vivado/RISC-V-toolchain
environment if available without delaying Variant A. Otherwise proceed to
Variant A and preserve this comparison as a reproducible, explicitly blocked
measurement attempt.

## Files created

* `experiments/processor_empirical_comparison/README.md`
* `experiments/processor_empirical_comparison/generate_vectors.py`
* `experiments/processor_empirical_comparison/generate_vectors.ps1`
* `experiments/processor_empirical_comparison/generate_custom_programs.ps1`
* `experiments/processor_empirical_comparison/tb_custom_scalar_comparison.sv`
* `experiments/processor_empirical_comparison/run_preflight.ps1`
* generated N=16/N=128 vectors, data memories, goldens and metadata
* `experiments/processor_empirical_comparison/preflight.json`
* `experiments/processor_empirical_comparison/preflight_results.csv`
* this report

Protected baseline RTL and historical benchmark evidence were not modified.

## R. Local-machine execution update (2026-10-11)

This section records the execution attempt on the current development machine,
separately from the earlier architecture comparison and bounded experiment
plan.

### R.1 Environment result

Git, MinGW GCC/make and an explicit local Python installation were available.
Vivado, XSim (`xvlog`, `xelab`, `xsim`), Vitis/XSCT, `mb-gcc`, RISC-V
bare-metal GCC, Verilator and Icarus Verilog were unavailable. No AMD/Xilinx
installation was found in the checked vendor directories. An Intel ModelSim
installation was present, but it does not provide the required Vivado/Vitis
flow. No packages, FPGA licenses or system-wide PATH settings were changed.
The complete audit is in
`experiments/processor_empirical_comparison/environment_manifest.md`.

### R.2 Executed checks

The existing preflight script ran successfully. Its five asset checks passed:
the N=16 golden, N=128 vector length, N=128 golden presence, and both custom
program memory-fit checks. An independent Python calculation also produced:

| Workload | Rows/products | Actual mathematical result | Golden | Status |
|---|---:|---:|---|---|
| N=16 | 16 | -106 / `0xFFFFFF96` | `0xFFFFFF96` | verified static |
| N=128 | 128 | 576 / `0x00000240` | `0x00000240` | verified static |

These are correctness checks of the deterministic assets, not processor cycle
measurements.

### R.3 What was not executed

The custom XSim testbench could not run because `xvlog`, `xelab` and `xsim`
were missing. Consequently no new dynamic custom scalar instruction/cycle
breakdown was claimed. PicoRV32 could not be compiled or simulated because
both the RISC-V GCC toolchain and a simulator were missing. MicroBlaze V could
not be configured because Vivado/Vitis and `mb-gcc` were missing. No new
same-device synthesis, WNS or Fmax result was generated. These are explicit
blockers, not estimates.

The inherited same-CPU reference remains unchanged: MAC8 134 cycles versus
DOT4ACC 43 cycles for the common 128-product comparison, approximately
3.116x. It is labelled inherited in the results CSV and was not silently
merged with the newly generated deterministic vectors.

### R.4 Updated answers to the final questions

1. **Did all three processors run N=128?** No. The deterministic N=128 workload was verified, but no processor RTL run was possible on this machine.
2. **Which processor had the best scalar cycles/MAC?** Not determined; no new scalar cycle result exists.
3. **How much of the custom weakness is software multiplication?** The absence of general multiply remains an architectural explanation supported by the prepared static program accounting, but its dynamic cycle/instruction fraction was not measurable in this environment.
4. **Is the custom pipeline/memory system credible?** The repository evidence remains credible and reports zero memory-wait cycles for the prior benchmark, but this run did not add new dynamic evidence. The missing multiply must not be conflated with a pipeline or BRAM failure.
5. **Is the 6.31x scalar-to-DOT4ACC result baseline-dependent?** Yes, it is platform-specific and partly baseline-dependent because the scalar ISA uses software multiplication. It must not be presented as a general comparison against mature scalar soft processors.
6. **Is MAC8-to-DOT4ACC stronger?** Yes. The inherited 134-to-43-cycle result controls the processor, memory system and software environment more tightly and is the stronger specialised-AI comparison.
7. **Best research platform rather than fastest?** On the evidence available, retain the custom CPU with external MicroBlaze V/PicoRV32 references. The complete RTL, counters, reproducibility and accelerator modifiability are directly relevant to the research question.
8. **Should Year III retain the custom CPU?** Yes, provisionally and with the stated caveats. The comparison should be rerun in a licensed/tool-complete environment if it can be done without delaying Variant A.
9. **Does this change Variant A?** No. It reinforces the need to investigate the next bottleneck after the inherited acceleration path rather than redesigning the processor or treating external-platform setup as the project contribution.

### R.5 Files added by this execution attempt

* `experiments/processor_empirical_comparison/environment_manifest.md`
* `experiments/processor_empirical_comparison/tool_setup_log.md`
* `experiments/processor_empirical_comparison/results.csv`
* `experiments/processor_empirical_comparison/platform_decision.md`

The preflight output was refreshed. No protected baseline RTL, historical
benchmark evidence, or existing reports were modified.

## S. Successful custom-CPU XSim execution (2026-10-11)

The Vivado 2026.1 environment became available after the earlier blocked
attempt. An experiment-local runner was added at
`experiments/processor_empirical_comparison/run_custom_xsim.ps1`. It compiled
the following dependency set with `xvlog`: `cpu_defs_pkg.sv`,
`bram_instr_mem.sv`, `bram_data_mem.sv`, `dot4acc_pipeline.sv`, the frozen
`cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`, and
`tb_custom_scalar_comparison.sv`. It then used `xelab` and `xsim` for both
macros, captured raw logs and emitted CSV/JSON results.

The first run exposed two experiment-asset defects, both corrected only in the
experiment-local generator: the STORE instruction used the ignored `rd` field
instead of `rs2` for store data, and negative numeric immediates were mistaken
for labels during program generation. The corrected images pass exact output
checks. The frozen RTL was not altered.

### S.1 Measured scalar results

| N | Expected/actual | Cycles | Retired | Loads | Stores | Branches (taken/not) | Jumps | Control flushes | Fetch waits | Memory waits | Data-hazard stalls | Load-use stalls | Cycles/MAC | Instructions/MAC |
|---:|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | `0xFFFFFF96` / pass | 168 | 163 | 32 | 1 | 0 (0/0) | 0 | 0 | 0 | 0 | 0 | 0 | 10.5000 | 10.1875 |
| 128 | `0x00000240` / pass | 6155 | 4037 | 256 | 1 | 960 (193/767) | 767 | 960 | 0 | 0 | 0 | 0 | 48.0859 | 31.5391 |

At the 93 MHz reference clock, the derived execution times are approximately
1.806 microseconds for N=16 and 66.183 microseconds for N=128. These are
derived from measured cycle counts and the target frequency, not measured FPGA
wall-clock timings.

### S.2 Software-multiply breakdown for N=128

The requested broader multiplication-loop accounting is 2,688 instructions.
Against 4,037 dynamically retired instructions this is 66.5841%; the residual
non-multiply count is 1,349 instructions. The testbench’s strict dynamic PC
classifier counted 2,432 instructions (60.2428%), with the additional 256
instructions in the 2,688 figure corresponding to the per-product setup path.
Both classifications identify the software multiplication path as the largest
retired-instruction category.

The remaining measured opcode counts were ADD 896, SUB 191, ADDI 966, LOAD
256, STORE 1, BEQ 960 and JUMP 767. The control path is therefore also
substantial: 960 branch decisions produced 960 control flush cycles, including
767 jump flushes. However, the run recorded zero fetch waits, zero memory waits,
zero data-hazard stalls and zero load-use stalls. The evidence supports the
following bounded interpretation: scalar weakness is dominated by the lack of
general multiply, with loop/control overhead a secondary cost; it is not
explained by BRAM wait states or observed pipeline hazard stalls.

### S.3 Current execution boundary

The custom CPU branch has now succeeded for both required workloads. PicoRV32
and MicroBlaze V were intentionally not started in this turn because the
approved execution order requires review of the custom XSim result first. No
external scalar ranking or same-device synthesis claim is yet added.

Raw evidence is stored in
`experiments/processor_empirical_comparison/custom_cpu/custom_xsim_results.csv`,
`custom_xsim_results.json`, and the per-case XSim logs. The consolidated table
is `experiments/processor_empirical_comparison/results.csv`.

## T. MicroBlaze V bounded attempt (2026-10-11)

The installed MicroBlaze V IP was confirmed at
`C:\AMDDesignTools\2026.1\data\ip\xilinx\microblaze_riscv_v1_0`. Its
component metadata identifies `xilinx.com:ip:microblaze_riscv:1.0` and exposes
local instruction/data LMB interfaces, integer multiply/divide configuration,
cache controls and custom-instruction controls. The intended configuration was
therefore aligned with the comparison requirements.

The empirical branch was stopped before system construction. Vivado 2026.1
launched, but both an in-memory project and an explicit experiment-local
project failed during project/application initialization with repeated
`[Common 17-354] Could not open 'C' for writing` errors. A reversible short-path
mapping attempt was denied by the local environment. This is a Vivado project
initialization/environment blocker, not evidence that the MicroBlaze IP is
missing.

No MicroBlaze V block design, BSP, benchmark binary, cycle count, Fmax or
resource result is claimed. PicoRV32 was not started because the requested
execution order requires MicroBlaze V success before proceeding. The blocker
logs and query scripts are retained under
`experiments/processor_empirical_comparison/microblaze_v/`.

## U. MicroBlaze V follow-up execution (2026-10-11)

The previous initialization blocker was resolved. Vivado 2026.1 successfully
created and validated an experiment-local MicroBlaze V design for
`xc7a35tcpg236-1` using `xilinx.com:ip:microblaze_riscv:1.0`. The design uses
the area-oriented three-stage setting (`C_OPTIMIZATION=1`), separate 32-bit
instruction/data LMBs, two 32 KiB BRAMs, caches disabled, counters enabled,
and no custom instruction interface or accelerator. `C_USE_MULDIV=1` enables
the combined RISC-V M extension. This IP does not expose independent
multiply/divide controls, so divider-only disablement could not be honoured and
is recorded as a limitation. The fixed hardware platform export succeeded as
`microblaze_v/project/mb_system_fixed.xsa` using `write_hw_platform -fixed`.

The Vitis platform flow then stopped at:

`Failed to create platform: mb_platform. Error in generating Processor List.`

The experiment-local HSI fallback reached standalone BSP generation but stopped
because it searched for
`C:/AMDDesignTools/2026.1/Vivado/gnu/riscv/nt/riscv64-unknown-elf/lib`, while
the installation provides its Xilinx RISC-V sysroot under `riscv32-xilinx-elf`.
No BSP-generated application, N=16/N=128 processor execution, cycle count,
instructions/MAC or execution time is claimed. The installed `mb-gcc` is the
classic MicroBlaze compiler and is not the correct compiler for this RISC-V IP.

As a limited software compatibility check, an experiment-local startup and
linker script compiled the exact signed-int8 benchmark at `-O2` with
`riscv64-unknown-elf-gcc`, `-march=rv32im_zicsr -mabi=ilp32`, and no libraries.
The valid RV32IM ELF contains hardware `mul`, `rdcycle` and `rdinstret`; this is
a build result, not an execution result. A same-part synthesis run with a
93 MHz clock constraint was started but did not complete within five minutes,
so no LUT, FF, DSP, BRAM, WNS or Fmax result is reported.

The MicroBlaze branch is therefore hardware-validated but empirically blocked.
The cross-processor scalar ranking remains unmeasured; the custom CPU's
6,155-cycle N=128 result and inherited MAC8/DOT4ACC results remain unchanged.

## V. External execution follow-up: PicoRV32 and MicroBlaze V

### V.1 PicoRV32 configuration and provenance

The official PicoRV32 repository was retrieved at commit
`ef203c2b0a3fb793280f5114941416c425c5b461`. The experiment uses
`ENABLE_REGS_DUALPORT=1`, `ENABLE_COUNTERS=1`, `ENABLE_COUNTERS64=1`,
`ENABLE_PCPI=0`, `ENABLE_MUL=1`, and `ENABLE_FAST_MUL=0`. It has no cache and
uses an experiment-local native valid/ready memory wrapper. The benchmark was
compiled with `riscv64-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -O2`
and no libraries.

The first run exposed and corrected a genuine ELF/reset issue: the linker
build-id note occupied address zero, so the reset vector would have executed
metadata. The experiment-local build now uses `--build-id=none`; disassembly
starts `_start` at `0x00000000`. Memory words are converted from the ELF binary
to little-endian hexadecimal words for XSim `$readmemh` loading.

### V.2 Measured PicoRV32 results

| N | Result | Cycles | Retired instructions | Cycles/MAC | Instructions/MAC | Time at 93 MHz |
|---:|---|---:|---:|---:|---:|---:|
| 16 | `0xFFFFFF96` PASS | 1,040 | 115 | 65.0000 | 7.1875 | 11.183 microseconds |
| 128 | `0x00000240` PASS | 8,208 | 899 | 64.1250 | 7.0234 | 88.258 microseconds |

Cycles and retired instructions are read from `mcycle`/`minstret` around the
dot-product body and exported through experiment-local memory-mapped status
writes observed by the XSim wrapper. The result checks are exact before the
values are accepted.

### V.3 PicoRV32 synthesis

An experiment-local top was synthesized on `xc7a35tcpg236-1` with Vivado
2026.1 and a 93 MHz clock constraint. Synthesis reported 10,006 LUTs, 869 FFs,
zero DSPs and zero BRAM tiles. The memory wrapper used asynchronous LUT-based
memory, so these resources are not directly comparable with the custom CPU's
BRAM-backed implementation. The synthesized timing report gave WNS 2.567 ns at
10.752 ns, corresponding to a 122.17 MHz timing estimate. This is synthesis
timing, not placed-and-routed Fmax.

### V.4 Updated external comparison

The custom CPU N=128 scalar result is 6,155 cycles / 48.0859 cycles per MAC,
versus PicoRV32's 8,208 cycles / 64.125 cycles per MAC in this bounded local
memory simulation. This does not establish general processor superiority:
PicoRV32's wrapper uses LUTRAM rather than the custom CPU's BRAM arrangement,
and the two simulations have different microarchitectural timing models. It
does establish that the custom scalar CPU is not automatically slower than a
realistic lightweight RISC-V core on this fixed kernel, despite its software
multiply limitation.

MicroBlaze V remains incomplete. Its generated simulation sources compile and
reach vendor-IP elaboration, but two runs were bounded at 180 seconds and 600
seconds respectively without reaching execution. The logs contain repeated
memory-model data-truncation warnings during BRAM initialization. Synthesis
was also bounded at 600 seconds after generated targets were available and did
not produce a completed run. No MicroBlaze cycle, instruction, resource or
Fmax value is claimed.

### V.5 Answers to the current execution questions

1. All three processors did not run N=128: the custom CPU and PicoRV32 did;
   MicroBlaze V stopped at vendor-IP elaboration/synthesis.
2. Of the measured scalar runs, the custom CPU was faster for this bounded
   simulation (48.0859 cycles/MAC versus PicoRV32's 64.125), but this is not a
   general processor ranking because the memory wrappers differ.
3. The custom scalar weakness is materially caused by software multiplication:
   2,688 broad multiply-loop instructions are 66.5841% of 4,037 retired
   instructions. The remaining cost includes 960 control flushes and 1,349
   non-multiply retired instructions; zero fetch, memory and hazard waits were
   observed.
4. The custom pipeline/memory path is credible for this experiment: local
   BRAM execution has zero observed wait or hazard stalls, and the measured
   control/multiply costs are visible in counters. This does not prove parity
   with mature cores.
5. The inherited 6.31x scalar-to-DOT4ACC Conv2 result is baseline-dependent
   because the scalar ISA lacks general multiply and pays software-loop cost.
6. MAC8 versus DOT4ACC remains the stronger controlled AI-acceleration claim:
   134 versus 43 cycles, approximately 3.116x, on the same CPU and workload
   definition.
7. The custom CPU remains the best research platform for this project, not
   because it is established or universally fastest, but because its RTL,
   counters, memory system and custom instruction path are fully controlled.
8. Retain the custom CPU and cite PicoRV32 as an external measured reference;
   keep MicroBlaze V as a documented hardware reference until its tool-flow
   blocker is independently resolved.
9. The comparison does not change the planned Variant A direction. It
   strengthens the case for investigating the next bottleneck after keeping
   scalar-baseline claims separate from the inherited AI accelerator study.
