# Bounded Cross-Processor Empirical Comparison

## Status

Plan revised and approved amendments incorporated. This directory contains
only new experiment assets. The protected baseline RTL, historical benchmark
evidence and existing reports are not modified.

## Objective

Test whether the frozen custom scalar CPU is an unusually weak reference before
using it to motivate Year III AI acceleration. Compare scalar execution only
against PicoRV32 and, if the existing Vivado/IP/compiler flow is readily
available, MicroBlaze V. Keep custom MAC8 and DOT4ACC as a separate same-CPU
acceleration study.

## Benchmark sizes

* N=16: bring-up and exact-correctness validation. Uses the previously defined
  deterministic vectors and expected result `0xFFFFFF96`.
* N=128: primary performance comparison. Uses deterministic signed-int8 data,
  exactly 128 MAC operations and one 32-bit modulo accumulator.
* N=512: not planned unless generation and execution are genuinely negligible.

## Frozen fairness rules

* signed int8 operands;
* signed 32-bit accumulator with modulo-2^32 result;
* local on-chip memory where practical;
* caches disabled where configurable;
* Vivado 2026.1 and `xc7a35tcpg236-1` where supported;
* 93 MHz reference target;
* `-O2` for primary compiled results; `-O0` only as an optional diagnostic;
* exact compiler, toolchain, ISA, multiplier and memory-interface settings
  recorded;
* deterministic start/done cycle measurement preferred;
* no accelerator or custom instruction on external scalar references;
* no direct claim that DOT4ACC beats either external processor.

## Processor configurations

### Custom CPU scalar

Use `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2` unchanged. Issue only
ADD, SUB, ADDI, LOAD, STORE, BEQ and JUMP. Multiplication is software-emulated
because the frozen scalar ISA has no general multiply. Record retired opcode
counts and classify scalar instructions as multiplication emulation,
load/store, address generation, loop/control, setup and other arithmetic.

### Custom CPU MAC8/DOT4ACC

Run only as a same-CPU specialised-acceleration control. Preserve the inherited
128-product results (MAC8 134 cycles, DOT4ACC 43 cycles) separately from any
new N=128 data if the mathematical vectors differ.

### PicoRV32

Attempt first with a minimal native valid/ready local-memory wrapper:

* dual-port registers;
* counters enabled;
* no PCPI accelerator;
* hardware multiply enabled for the primary realistic scalar result;
* optional no-multiply and fast-multiply runs only if negligible;
* caches absent and local memory response deterministic.

Record the exact repository commit, compiler, flags, binary hash, memory timing,
clock and correctness result.

### MicroBlaze V

Attempt only if the installed Vivado/IP/compiler flow is usable without major
BSP, AXI, linker, debug or board-support development. Prefer a 32-bit,
area-oriented scalar configuration with caches disabled, local BRAM, divider
disabled, no custom instructions and the normal realistic hardware multiplier.

## Stop conditions

Stop an external-processor branch if the toolchain is unavailable, deterministic
measurement is impractical, substantial system integration is required, or the
work begins to consume disproportionate Variant A development time. Preserve
logs and document the blocker; do not fabricate empirical values.

## Required evidence

Every successful run must record N=16 and N=128 expected/actual results, cycle
measurement method, source/binary hash, configuration manifest and raw metrics.
Resource/Fmax values are directly comparable only when device, speed grade,
Vivado version, wrapper scope and memory assumptions match.

## Planned report

The final report is `docs/fyp/processor_empirical_comparison.md` and will cover
objective, benchmark, assumptions, custom scalar breakdown, PicoRV32 result,
MicroBlaze result or blocker, same-CPU MAC8/DOT4ACC results, cross-processor
comparison, limitations, platform recommendation and Jira summary.
