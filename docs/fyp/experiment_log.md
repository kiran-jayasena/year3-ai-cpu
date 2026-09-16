# FYP Experiment Log

Copy the template below for each experiment. Do not reuse an experiment ID.

## Experiment template

**Experiment ID:**

**Date:**

**Commit SHA:**

**Research question:**

**Hypothesis:**

**Baseline:**

**Architectural change:**

**Expected outcome:**

**Verification result:**

**Benchmark:**

**Cycles:**

**Validated frequency:**

**Resources:**

**Power:**

**Energy/workload:**

**Result:** ACCEPT / REJECT / INCONCLUSIVE

**Interpretation:**

**Next step:**

---

## FYP-EXP-001 — Baseline AI Workload Characterisation and Bottleneck Analysis

**Status:** PLANNED

**Date:** 2026-09-16

**Commit SHA:** Baseline RTL under test:
`2731a7820988863829c7074acd474ea06902e8f2`. The first measurement record must
also capture the exact active FYP commit.

**Research question:** Where does the existing single-core AI architecture lose
performance between peak/register-resident arithmetic and complete AI-style
workloads?

**Objective:** Reproduce or re-measure the frozen baseline at register-resident,
memory-fed and complete-workload levels, then identify the dominant practical
limitation without changing the CPU architecture.

**Hypothesis:** The existing CPU is expected to show a measurable gap between
register-resident DOT throughput and complete AI workload throughput. The
experiment will determine whether the dominant source is data movement,
instruction/control overhead, dependency stalls, arithmetic utilisation or
another architectural effect.

**Baseline:** Frozen H1.3b functional architecture and H1.3b-T2 physical
implementation. Summer Stage H, J and L results are prior-work references, not
new FYP measurements.

**Architectural change:** None. This is a measurement and characterisation
experiment.

**Metrics:** Correctness; useful MACs; cycles; retired instructions; instruction
mix; available stall/hold counters; MAC/cycle; validated MHz; MMAC/s; execution
time; and retained LUT, FF, BRAM, DSP and timing evidence with provenance.

**Acceptance criterion:** All reproduced workloads must be self-checking and
correct; every result must record its source testbench, command, commit and
provenance. A bottleneck conclusion requires mutually consistent counter,
instruction-mix and throughput evidence. Otherwise the result is mixed or
inconclusive.

**Power:** Not required to be re-measured in EXP-001 preparation.

**Energy/workload:** Not calculated until a valid power methodology is
established.

**Result:** PLANNED

**Next decision dependency:** EXP-002 must be selected from the measured
dominant limitation; no scratchpad, wider arithmetic, control restructuring or
new instruction is selected in advance.
