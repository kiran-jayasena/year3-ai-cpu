# KAN-63 — Stage 4 Baseline Evidence Freeze

## Purpose

This package freezes one authoritative, reproducible Stage 4 baseline for later Variant A comparisons. It consolidates the retained KAN-57 resource, KAN-58 performance, KAN-59 power/energy and KAN-62 bottleneck evidence without changing the design or recomputing the workload.

## Baseline identity

- Stage 3 hardware tag: `fyp-stage3-baseline`
- Stage 3 hardware commit: `f6b25ca196493858cc2b501a0324c4a794c0dd94`
- CPU: `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2`
- Top: `fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2`
- Board/device: Digilent Basys 3 / `xc7a35tcpg236-1`
- Vivado/XSim: 2026.1, build 6511674
- Development branch: `fyp-development`

## Workload identity

The measured workload is the validated Conv2-derived quantised representative tile from the frozen MNIST CNN: sample index 2, output channel 0, input channel 0, 2x2 output tile. It performs 4 outputs x 9 products = 36 MAC-equivalent operations. It is scalar software; the physically present DOT4ACC/MAC8 path is not issued. Golden output is `[-116, 15, -97, 90]`.

## Consolidated frozen metrics

| Category | Metric | Frozen baseline |
|---|---|---:|
| Identity | Stage 3 tag | `fyp-stage3-baseline` |
| Identity | Frozen commit | `f6b25ca196493858cc2b501a0324c4a794c0dd94` |
| Platform | FPGA | `xc7a35tcpg236-1` |
| Timing | Validated frequency | 93.000 MHz |
| Workload | Useful MAC-equivalent operations | 36 |
| Workload | Golden output | `[-116, 15, -97, 90]` |
| Resources | LUTs | 2,008 (9.65%) |
| Resources | FFs | 1,812 (4.36%) |
| Resources | DSPs | 5 (5.56%) |
| Resources | BRAM tiles | 1 (2.00%) |
| Resources | RAMB18 | 2 |
| Performance | Cycles | 1,464 |
| Performance | Retired instructions | 962 |
| Performance | CPI | 1.5218295 |
| Performance | Instructions/MAC | 26.7222222 |
| Performance | Cycles/MAC | 40.6666667 |
| Performance | Execution time | 15.741935 us |
| Power | Total on-chip power | 0.086 W |
| Power | Static/device power | 0.072 W |
| Power | Dynamic power | 0.014 W |
| Energy | Total energy/workload | 1.353806 uJ |
| Energy | Dynamic energy/workload | 0.220387 uJ |
| Energy | Total energy/MAC | 37.605735 nJ/MAC |
| Bottleneck | Primary observed classification | Scalar instruction and control-flow overhead |

Additional KAN-57 resources: LUTRAM 0, IOBs 19/106 (17.92%), BUFG 1. Hierarchy includes `dot4acc_pipeline_inst` (545 LUTs, 96 FFs, 4 DSPs), `data_mem_inst` (329 LUTs, one RAMB18) and `instr_mem_inst` (171 LUTs, one RAMB18).

## Bottleneck evidence carried forward

KAN-62 measured 216 arithmetic/accumulation instructions, 109 loads, 5 stores, 112 address-generation instructions, 144 loop-counter updates, 9 immediate setup instructions, 216 conditional branches and 151 jumps. Of 502 cycles above the CPI=1 reference, 6 were pipeline fill and 216 were measured control-hazard flushes; 280 remained unclassified. No data-hazard, load-use or memory-wait cycles were measured. The evidence-backed classification is dominant scalar instruction-count and branch/control overhead; significant address/loop bookkeeping and scalar arithmetic; memory waits and pipeline hazards not supported as dominant; Fmax not supported as the workload bottleneck.

## Evidence provenance

The authoritative raw evidence remains in the original KAN directories indexed by `evidence_index.md`. Source commits are recorded in `baseline_manifest.json`. No metric was silently regenerated using a different revision or workload.

## Variant A comparison contract

Later variants must preserve the same logical tile, 36-operation useful-work convention, golden output requirement, FPGA device, counter semantics, resource-reporting method and power methodology wherever possible. Any change to precision, workload size, memory placement, clock frequency or activity methodology must be disclosed. Report speed-up as `baseline_cycles / variant_cycles`, resource overhead relative to this baseline, and energy improvement using equivalent workload and power methods.

## Limitations

See `limitations.md`. In particular, this is a representative kernel rather than full MNIST inference, scalar software does not exercise DOT4ACC/MAC8, and the power result is a vectorless Vivado estimate rather than board measurement.

## Freeze statement

The Stage 4 baseline evidence package is frozen as the repository state identified by the annotated tag `fyp-stage4-evidence-freeze`. The existing `fyp-stage3-baseline` tag is preserved and is not moved. No RTL, ISA, memory, workload, timing constraint or clocking changes were made.
