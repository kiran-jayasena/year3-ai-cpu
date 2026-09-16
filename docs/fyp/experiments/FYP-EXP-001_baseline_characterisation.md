# FYP-EXP-001 — Baseline AI Workload Characterisation and Bottleneck Analysis

## Status and scope

**Status:** PLANNED

**Experiment type:** Measurement and characterisation

**Baseline architecture:** H1.3b functional core / H1.3b-T2 physical baseline

**Frozen baseline commit:** `2731a7820988863829c7074acd474ea06902e8f2`

FYP-EXP-001 does not alter the CPU architecture. It establishes a quantitative
baseline before EXP-002 selects any architectural investigation. Existing
summer results are prior work and are labelled as references until independently
reproduced under the FYP methodology.

## Research question

Where does the existing single-core AI architecture lose performance between
peak/register-resident arithmetic and complete AI-style workloads?

## Purpose and neutral hypothesis

The purpose is to measure the gap between arithmetic-focused and complete
workloads, attribute it only as far as the existing evidence permits, and use
that evidence to select EXP-002.

The existing CPU is expected to show a measurable gap between
register-resident DOT throughput and complete AI workload throughput.
FYP-EXP-001 will determine whether the dominant source of this gap is data
movement, instruction/control overhead, dependency stalls, arithmetic
utilisation, or another architectural effect.

Memory is therefore a candidate explanation, not a predetermined conclusion.

## Prior-work reference points

These values came from work completed before the Year 3 project. They are
comparison targets for reproduction, not new FYP measurements.

| Level | Workload | Useful work | Prior cycles | Prior throughput at 93 MHz | Prior result |
|---|---|---:|---:|---:|---|
| A | Register-resident DOT4ACC, N=128 | 128 MACs | 43 | 276.8372 MMAC/s | `0x00004f25` |
| B | Stage H memory-fed DOT4ACC, N=128 | 128 MACs | 263 | approximately 45.26 MMAC/s | `0x00004f25` |
| C | Stage J J1 complete dot product, N=128 | 128 MACs | 358 | 33.2514 MMAC/s | `0x000028e5` |
| D | Stage J J2 matrix-vector, 2x64 | 128 MACs | 331 | 35.9637 MMAC/s | `0x000024e5`, `0x0000bf7b` |

Level A is a near-arithmetic reference point because operands are preloaded in
registers. Level B adds operand loads. Levels C and D add complete program data
layout, pointer/address work and output stores. Differences between levels are
not automatically attributable to a single cause.

## Authoritative existing testbenches

### A — Register-resident DOT reference

- Testbench: `tb/tb_dot4acc_stage_l_comparison.sv`
- Top module: `tb_dot4acc_stage_l_comparison`
- Dedicated existing run script: none found
- Workload: the four-lane signed pattern is repeated 32 times, for N=128 and
  128 useful MACs; 32 DOT4ACC instructions and one STORE retire
- Golden result: `0x00004f25`
- Prior cycle metric: 43 cycles; 33 retired instructions; zero aggregate stall
  cycles in the retained Stage L CSV
- Self-checking: yes; timeout or DOT result mismatch calls `$fatal`

### B — Stage H memory-fed DOT reference

- Testbench: `tb/tb_dot4acc_stage_h13b_timingopt_t2_benchmark.sv`
- Top module: `tb_dot4acc_stage_h13b_timingopt_t2_benchmark`
- Dedicated existing run script: none found
- Workload: N=16/32/64/128 are present; EXP-001 uses N=128 as the headline
  comparison, comprising 64 LOADs, 32 DOT4ACC instructions and one STORE for
  128 useful MACs
- Golden result: repeated reference-model result `0x00004f25` at N=128
- Prior cycle metric: 263 cycles, 97 retired instructions and 129 aggregate
  DOT/frontend-hold cycles for N=128 in the retained output
- Self-checking: yes; reference-model result, instruction-count invariants,
  timeout checks and a final `$fatal` on any failed check

This testbench writes the historical `reports/dot4acc_stage_e/results.csv`
path even though it instantiates the frozen H1.3b-T2 core. EXP-001 must capture
new raw output under `reports/fyp/experiments/FYP-EXP-001/` and must not silently
replace retained summer evidence.

### C and D — Stage J complete workloads

- Testbench: `tb/tb_dot4acc_stage_j_ai_workload.sv`
- Top module: `tb_dot4acc_stage_j_ai_workload`
- Dedicated existing run script: none found
- J1 workload: N=32/64/128 complete dot products; EXP-001 headline is N=128,
  128 useful MACs, golden result `0x000028e5`
- J2 workload: two-output 64-element matrix-vector operation, 128 useful MACs,
  golden outputs `0x000024e5` and `0x0000bf7b`
- Prior cycle metrics: J1 N=128 is 358 cycles and 161 retired instructions;
  J2 is 331 cycles and 134 retired instructions
- Self-checking: partial. The testbench compares and prints every golden result
  and records PASS/FAIL in its CSV, but only a timeout calls `$fatal`; a result
  mismatch does not currently produce a non-success simulator exit. The
  EXP-001 runner must parse every result check and fail if any row is not PASS.

### Existing reusable runner infrastructure

`scripts/run_xsim_dot4acc_stage_e.ps1` demonstrates Vivado 2026.1 tool
discovery, compile/elaborate/run sequencing, failure detection and CSV checks.
It targets the earlier Stage E core and `tb/tb_dot4acc_stage_e_benchmark.sv`, so
its results are not an H1.3b-T2 reproduction. `scripts/run_xsim_regression.ps1`
also includes that Stage E test, but not the three frozen-baseline entry points
above. The complete historical regression is not required for EXP-001.

## Instrumentation audit

### Available now

The frozen core exposes direct RTL counters for:

- total cycles and retired instructions;
- pipeline-fill cycles;
- data-hazard and load-use stall cycles;
- control-hazard flush cycles and wrong-path instructions flushed;
- instruction-fetch wait cycles and `memory_wait_cycles` (currently incremented
  with `decode_stall`, so its name must not be interpreted as all memory delay);
- taken/not-taken branch counts and jump count.

The frozen core also exposes event or state signals for DOT issue/accept,
completion and retirement; source and accumulator dependency stalls; DOT
frontend hold; DOT activity; and cancellation. Its retirement interface exposes
the opcode and STORE metadata for each retired instruction.

Existing testbenches already derive or can derive without RTL changes:

- LOAD, STORE, DOT4ACC, MAC8, scalar and branch/control instruction counts from
  the retirement stream;
- DOT issue-event count from `dot_issue_accept`;
- expected and actual results, PASS/FAIL, cycles and retired instructions;
- an aggregate hold count. Stage J defines this as the OR of
  `dot_frontend_hold`, `scalar_overlap_hold`, `dot_issue_stall` and
  `decode_stall`, so it is a workload-level aggregate, not an exclusive root
  cause;
- the Stage H benchmark's deterministic diagnostic partition into load-use,
  DOT hold, DOT issue, DOT completion, DOT retirement, fetch/wait and residual
  cycles, plus second-LOAD ownership events.

### Not currently measured as a trustworthy standalone quantity

- a mutually exclusive full split of all cycles into arithmetic, data movement,
  scalar/control, dependency, memory-feed and pipeline overhead;
- pure memory-feed stall cycles separated from overlapping frontend/scalar
  holds;
- data-movement cycles distinct from the cycles in which LOAD/STORE instructions
  retire;
- arithmetic-unit busy/idle utilisation independent of issue-event inference;
- branch/control penalty for these unrolled benchmarks beyond the existing
  general counters (the retained J1/J2 branch count is zero);
- energy per workload, because a valid FYP power methodology is not yet
  established;
- independently reproduced FYP timing or resource results.

No new RTL counters will be added in EXP-001 preparation. Testbench observation
may be extended later only if the measurement definition and provenance remain
clear.

## Measurement and attribution model

The desired conceptual model is:

```text
total cycles
  = useful arithmetic work
  + memory/data movement
  + scalar/address/control instructions
  + dependency stalls
  + memory-feed stalls/holds
  + pipeline/control overhead
```

This is an analysis model, not an assertion that the existing signals form
mutually exclusive counters. Several events can overlap in one cycle.

- **Directly measured:** RTL counters and sampled event signals, retirement
  opcodes, golden/actual outputs and elapsed enabled cycles.
- **Derived:** instruction mix from retirement opcodes, useful MACs from the
  declared workload, MAC/cycle, MMAC/s and execution time.
- **Estimate/inference:** residual-cycle attribution, issue-based arithmetic
  utilisation and any grouping of aggregate holds into a dominant cause.

Any inferred residual must be labelled and must not be presented as a precise
counter. The Stage H diagnostic priority partition may be reproduced as a
diagnostic view, but its category names do not prove physical exclusivity.

## Metrics and formulas

Each reproduced row will record, where available:

- correctness: expected result, actual result and PASS/FAIL;
- work: useful MACs;
- execution: cycles and retired instructions;
- instruction mix: LOAD, STORE, DOT4ACC, MAC8, scalar and branch/control counts;
- pipeline: aggregate stall/hold, load-use/dependency observations,
  memory-related observations and DOT issue events;
- arithmetic utilisation: `MAC/cycle = useful MACs / cycles`;
- physical throughput: validated frequency, `MMAC/s = MAC/cycle × MHz`, and
  `execution_us = cycles / MHz`;
- FPGA: LUT, FF, BRAM18 and DSP48;
- timing: setup WNS, TNS and hold WNS.

Power is not required to be re-measured in this task. Energy is not calculated
until a valid power methodology is established.

## Physical baseline provenance

The retained physical baseline is prior work:

- 93 MHz, PASS 5/5;
- setup WNS `+0.230 ns`, TNS `0 ns`, hold WNS `+0.059 ns`;
- 2008 LUT, 1812 FF, 2 RAMB18 and 5 DSP48.

These values may accompany a row only as `prior_work_reference`. They are not
independently reproduced FYP physical results unless a later controlled Vivado
implementation run reproduces them. EXP-001 preparation does not run Vivado
place-and-route.

## Reproduction procedure and provenance

For every future run, capture the exact Git SHA, testbench, top module, source
list, command, Vivado/XSim version, PASS/FAIL marker, expected and actual
results, cycles and emitted counters. Store compact logs and extracts under
`reports/fyp/experiments/FYP-EXP-001/`; do not commit generated Vivado/XSim
project trees.

Rows copied from retained reports use `prior_work_reference`. Only a newly run,
logged and traceable test may use `reproduced_fyp_measurement`.

The exact focused H1.3b-T2 XSim command is not retained as an existing script.
Until a reviewed wrapper prevents historical CSV paths from being overwritten,
the run status is: **RUN COMMAND REQUIRES REVIEW**.

## Acceptance criterion and EXP-002 decision rule

EXP-001 is complete when all four headline levels have traceable correctness
and cycle results, available instruction/counter evidence has been captured,
and the arithmetic-to-application gap has been classified without fabricated
precision.

- If data-delivery evidence dominates, EXP-002 may investigate local buffering
  or scratchpad-style delivery.
- If arithmetic capacity dominates, EXP-002 may investigate wider or vector
  arithmetic.
- If timing/control evidence dominates, EXP-002 may investigate pipeline or
  control restructuring.
- If instruction overhead dominates, EXP-002 may investigate ISA/data-access
  integration.
- If dependency evidence dominates, EXP-002 may investigate scheduling,
  forwarding or pipeline dependency handling.
- If evidence is overlapping, close or contradictory, classify the limitation
  as mixed or inconclusive and design a narrower measurement before EXP-002.

These are decision branches, not selected designs. A dominant limitation must
be supported by consistent throughput, instruction-mix and counter evidence;
EXP-002 must cite that evidence.
