# KAN-59 Baseline Power and Energy Estimate

## Baseline and methodology

| Metric | Baseline |
|---|---|
| Baseline tag | `fyp-stage3-baseline` |
| Commit | `f6b25ca196493858cc2b501a0324c4a794c0dd94` |
| Top | `fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2` |
| FPGA/board | `xc7a35tcpg236-1` / Basys 3 |
| Vivado | 2026.1 build 6511674 |
| Frequency | 93.000 MHz |
| Workload cycles | 1,464 |
| Execution time | 15.741935 µs |
| Useful MAC-equivalent operations | 36 |
| Activity methodology | Vivado vectorless/default activity propagation |
| Simulation activity file | None available or applied |
| Vivado confidence | Medium |

## Power breakdown

| Component | Power |
|---|---:|
| Total on-chip power | 0.086 W |
| Device/static power | 0.072 W |
| Dynamic power | 0.014 W |
| Clock power | 0.006 W |
| Slice logic power | <0.001 W |
| Signal/routing power | <0.001 W |
| BRAM power | 0.003 W |
| DSP power | 0.000 W |
| I/O power | 0.004 W |

The component values are Vivado's displayed rounded values; the raw report is authoritative.

## Energy per KAN-58 execution

Using the measured KAN-58 duration, not a nominal workload duration:

`execution_time_s = 1464 / 93,000,000 = 0.000015741935484 s`

| Metric | Result |
|---|---:|
| Total energy/workload | 1.353806 µJ |
| Dynamic energy/workload | 0.220387 µJ |
| Total energy/MAC-equivalent | 37.605735 nJ/MAC |
| Dynamic energy/MAC-equivalent | 6.121864 nJ/MAC |

## Interpretation limits

This is a vectorless Vivado estimate with Medium confidence, not a physical board measurement and not workload-derived switching activity. The complete baseline design, including the physically present `dot4acc_pipeline_inst` and four DSP48E1 resources, is included. KAN-58 does not issue DOT4ACC/MAC8 instructions, so that datapath is not exercised by the measured benchmark.

No RTL, ISA, memory, timing constraint, clocking, workload, or accelerator changes were made. No KAN-62 bottleneck analysis is performed.

