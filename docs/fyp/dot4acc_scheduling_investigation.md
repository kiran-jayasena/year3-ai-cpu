# DOT4ACC NOP Scheduling Investigation

## Executive result

The frozen Conv2 benchmark’s 160 scheduled NOPs were unnecessary for the
tested active RTL. A dependency-aware sweep removed them progressively and
then completely without changing the 12 DOT4ACC operations, 24 loads, 5
stores or exact outputs.

| Schedule | NOPs | Cycles | Retired | Fetch waits | Result |
|---|---:|---:|---:|---:|---|
| Original 6/10 | 160 | 232 | 207 | 20 | PASS |
| 5/9 | 136 | 208 | 183 | 20 | PASS |
| 4/8 | 112 | 184 | 159 | 20 | PASS |
| 3/7 | 88 | 160 | 135 | 20 | PASS |
| 2/6 | 64 | 136 | 111 | 20 | PASS |
| 1/5 | 40 | 112 | 87 | 20 | PASS |
| 0/4 | 16 | 88 | 63 | 20 | PASS |
| 6/0 | 120 | 192 | 167 | 20 | PASS |
| 0/10 | 40 | 112 | 87 | 20 | PASS |
| 0/0 | **0** | **72** | **47** | **20** | **PASS** |

The first number is the load-to-load NOP gap; the second is the final
load-to-DOT-chain gap. Every row also measured zero memory waits, zero data
hazard stalls and zero load-use stalls.

## Reproduction

The audit was performed from branch `fyp-development` at commit `bd802ce`
(`docs: record hazard verification and DOT4ACC bottleneck study`). The
experiment files are intentionally uncommitted working-tree artifacts; no
baseline RTL, benchmark image or Jira issue was changed.

From the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File experiments/dot4acc_nop_scheduling/run_nop_sweep.ps1
```

The script generates isolated images, compiles the frozen RTL and
`tb_dot4acc_nop_schedule.sv` with Vivado/XSim 2026.1, and writes:

- `experiments/dot4acc_nop_scheduling/dot4acc_nop_scheduling_results.csv`
- one generated `.mem` image and `.log` per schedule

The original image checksum before the experiment was:

`62C8787C2390006EF6216286FB7825E1D7B05B5C02485054BA740D000FAD7639`

for `programs/kan50_conv2_tile_dot4acc_scheduled.mem`.

The active-core architectural regression was also rerun:

```powershell
xvlog -sv rtl/cpu_defs_pkg.sv tb/dot4acc_reference_pkg.sv rtl/bram_instr_mem.sv rtl/bram_data_mem.sv rtl/dot4acc_pipeline.sv rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv tb/tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv
xelab tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 -s nop_schedule_active_regression_sim
xsim nop_schedule_active_regression_sim -runall
```

Result: **4,254 checks, 0 failures**.

## Performance interpretation

NOP removal reduced Conv2 execution by 160 cycles, from 232 to 72:

- NOP reduction: 100%.
- Retired-instruction reduction: 160/207 = 77.29%.
- Cycle reduction: 160/232 = 68.97%.
- Speed-up: 232/72 = 3.22x.
- MAC-equivalent throughput: 36/232 = 0.155 MAC/cycle originally;
  36/72 = 0.500 MAC/cycle after scheduling.
- Fetch waits: unchanged at 20.
- Memory waits and hazards: unchanged at zero.

This is a software/benchmark scheduling improvement, not new hardware
acceleration. It must be applied before claiming any further hardware speed-up
over Conv2.

## Scaling result

The existing KAN-360 scaling test already uses compact LOAD/LOAD/DOT sequences
with no scheduled NOPs. Re-running it produced the same results:

| Workload | Original compact schedule | NOP-optimised schedule | Change |
|---|---:|---:|---:|
| Small, 16 MACs | 39 cycles | 39 cycles | 0 |
| Medium, 64 MACs | 135 cycles | 135 cycles | 0 |
| Large, 128 MACs | 263 cycles | 263 cycles | 0 |

The slope remains `cycles = 7 + 8*DOT_groups`, with fetch waits growing by
approximately three per DOT group. Therefore NOP removal explains the
Conv2-specific 232-cycle overhead but does not explain or remove the scalable
KAN-360 load/load/DOT cost.

## Decision

The NOP investigation changes the fair baseline, but it does not eliminate the
case for a hardware operand-delivery investigation. A fused load-load-DOT4ACC
command remains justified for the scaling bottleneck, but it must be compared
against the corrected 72-cycle Conv2 software baseline and the already compact
39/135/263 scaling baseline.

The revised target should not claim that simply reaching 72 cycles is a
hardware result. Any Variant A gain must exceed the software schedule gain and
show a reduction in the compact scaling slope.
