# KAN-56 Timing-Clean Baseline Frequency

## Objective

Establish a repeatable timing-clean operating point for the frozen Stage 3 baseline without changing the design. This task varies only the clock period and preserves implementation evidence for later apples-to-apples comparisons.

## Frozen baseline

- Tag: `fyp-stage3-baseline`
- Commit: `f6b25ca196493858cc2b501a0324c4a794c0dd94`
- CPU: `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2`
- Top: `fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2`
- FPGA: `xc7a35tcpg236-1` / Basys 3
- Vivado: 2026.1, build 6511674
- Workspace: `C:\FPGA\kan56-timing-sweep`

## Method

The existing `scripts/run_vivado_impl_dot4acc_stage_h13b_timingopt_t2.tcl` flow was run in a clean frozen-baseline clone. It used the established five-argument interface and default synthesis/placement/routing directives. Only the generated clock-period override differed between timing points.

A point was accepted only if route completed, WNS was at least zero, TNS was zero, and worst hold slack was at least zero.

## Sweep results

| Period (ns) | Frequency (MHz) | WNS (ns) | TNS (ns) | Worst hold (ns) | Route | Setup | Hold | Result |
|---:|---:|---:|---:|---:|---|---|---|---|
| 10.50 | 95.238 | -0.288 | -12.322 | +0.060 | PASS | FAIL | PASS | FAIL |
| 10.25 | 97.561 | -0.967 | -171.010 | +0.060 | PASS | FAIL | PASS | FAIL |
| 10.00 | 100.000 | -0.623 | -71.487 | +0.057 | PASS | FAIL | PASS | FAIL |
| 9.75 | 102.564 | -1.165 | -327.124 | +0.056 | PASS | FAIL | PASS | FAIL |
| 10.70 | 93.458 | -0.157 | -1.713 | +0.038 | PASS | FAIL | PASS | FAIL |
| 10.752688172 | 93.000 | +0.230 | 0.000 | +0.059 | PASS | PASS | PASS | PASS |

The four initial points were intentionally retained even though their setup results are non-monotonic because placement and routing can change with the constrained period. The 10.70 ns point is the first tighter point tested immediately above the accepted point and fails setup timing.

Resource structure remained consistent across the sweep: registers stayed at 1,812, RAMB18 at 2, RAMB36 at 0, DSP48 at 5, and BUFG at 1. Vivado's constraint-dependent implementation produced LUT counts from 1,996 to 2,022 across the exploratory points; the three accepted repeats were identical at 2,008 LUTs.

## Repeatability

The accepted 10.752688172 ns / 93.000 MHz point was implemented three times. All three runs produced identical raw timing values: WNS `+0.230 ns`, TNS `0.000 ns`, and worst hold slack `+0.059 ns`. All routed successfully and produced identical resource counts: 2,008 LUTs, 1,812 registers, 2 RAMB18, 5 DSP48, and 1 BUFG.

The third repeat took substantially longer during Vivado placement than the first two. The shell wrapper timed out while waiting, but the Vivado process completed and wrote its complete `run_result.csv` and timing reports; those raw files, rather than the truncated console tail, are used for the repeatability result.

## Critical-path evidence

Accepted clean point (`critical_path_clean.rpt`):

- Startpoint: `cpu_inst/data_mem_inst/mem_reg/CLKARDCLK`
- Endpoint: `cpu_inst/id_ex_reg_reg[operand_b][16]/R`
- Data path delay: 9.878 ns
- Logic delay: 4.651 ns
- Routing delay: 5.227 ns
- Logic levels: 12

First tested failing point (`critical_path_fail.rpt`, 10.70 ns):

- Startpoint: `cpu_inst/data_mem_inst/mem_reg/CLKARDCLK`
- Endpoint: `cpu_inst/id_ex_reg_reg[operand_a][13]/R`
- Data path delay: 10.222 ns
- Logic delay: 4.491 ns
- Routing delay: 5.731 ns
- Logic levels: 11
- WNS: -0.157 ns; TNS: -1.713 ns

These are implementation timing paths only. They are not asserted to be AI-workload bottlenecks.

## Conclusion

KAN-56 established the repeatable timing-clean operating point of the frozen `fyp-stage3-baseline` on `xc7a35tcpg236-1` using Vivado 2026.1. Only the requested clock period was varied; RTL, ISA, implementation strategy, and all other constraints remained unchanged. The highest repeatably timing-clean tested point was **93.000 MHz at 10.752688172 ns**, while the next tighter tested point at **93.457944 MHz / 10.70 ns** failed setup timing. This value defines the physical timing baseline for later apples-to-apples comparison. No workload bottleneck or accelerator conclusion is made.
