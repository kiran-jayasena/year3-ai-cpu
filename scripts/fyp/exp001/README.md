# FYP-EXP-001 run plan

## Scope

Run only focused Vivado XSim simulations for the frozen H1.3b-T2 baseline. Do
not run the complete historical regression or any Vivado synthesis,
implementation, place-and-route or bitstream flow as part of EXP-001
functional measurement.

## Existing reusable scripts

- `scripts/run_xsim_dot4acc_stage_e.ps1` is a lightweight, self-checking XSim
  runner and is useful as a wrapper pattern. It runs the earlier Stage E core,
  not the frozen H1.3b-T2 baseline, so its output must not be entered as an
  EXP-001 reproduction.
- `scripts/run_xsim_regression.ps1` is the complete historical regression. It
  is expensive relative to the focused tests and is not required unless a
  focused failure needs broader diagnosis. It does not currently include the
  frozen Stage H-T2, Stage J or Stage L benchmark tops.

No dedicated existing runner was found for the three authoritative frozen
baseline testbenches below. **RUN COMMAND REQUIRES REVIEW** before the first
measurement, principally because the testbenches write retained historical CSV
paths and EXP-001 must not overwrite prior-work evidence.

## Focused test matrix

| Workload | Testbench | Top | Expected compact output | EXP-001 destination | Cost |
|---|---|---|---|---|---|
| Register DOT N128 | `tb/tb_dot4acc_stage_l_comparison.sv` | `tb_dot4acc_stage_l_comparison` | PASS marker; 43 cycles; `0x00004f25` | `reports/fyp/experiments/FYP-EXP-001/register_resident_dot.log` and `results.csv` | Lightweight XSim |
| Memory-fed DOT N128 | `tb/tb_dot4acc_stage_h13b_timingopt_t2_benchmark.sv` | `tb_dot4acc_stage_h13b_timingopt_t2_benchmark` | suite PASS; N128 263 cycles; `0x00004f25` | `reports/fyp/experiments/FYP-EXP-001/memory_fed_dot.log` and `results.csv` | Lightweight/focused XSim, but broader benchmark cases |
| Stage J J1/J2 | `tb/tb_dot4acc_stage_j_ai_workload.sv` | `tb_dot4acc_stage_j_ai_workload` | J1/J2 golden outputs, cycle/count lines and PASS for every row; the final marker alone is insufficient | `reports/fyp/experiments/FYP-EXP-001/stage_j.log` and `results.csv` | Lightweight XSim |

## Verified source sets for a future wrapper

Stage H benchmark sources:

```text
rtl/cpu_defs_pkg.sv
tb/dot4acc_reference_pkg.sv
rtl/bram_instr_mem.sv
rtl/bram_data_mem.sv
rtl/dot4acc_pipeline.sv
rtl/cpu_core_pipeline_mac8_timingopt.sv
rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv
tb/tb_dot4acc_stage_h13b_timingopt_t2_benchmark.sv
```

Stage J and Stage L use:

```text
rtl/cpu_defs_pkg.sv
rtl/bram_instr_mem.sv
rtl/bram_data_mem.sv
rtl/dot4acc_pipeline.sv
rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv
<selected Stage J or Stage L testbench>
```

The first reviewed wrapper should call `xvlog -sv`, `xelab <top> -s
<unique_snapshot>` and `xsim <unique_snapshot> -runall`, stop on every non-zero
exit code or failure marker, and run in an isolated working directory so the
hard-coded summer CSV destinations cannot be modified. For Stage J it must also
fail if any printed or CSV result check is not PASS, because the current
testbench only calls `$fatal` on timeout.

## Required capture

Before each run, record `git rev-parse HEAD`. Capture:

- commit SHA and clean/dirty status;
- testbench, top, source list and exact command;
- Vivado/XSim version;
- PASS/FAIL, expected result, actual result and cycles;
- emitted instruction counts, hold/stall counts and DOT issue events; and
- start/end time if useful.

Write only compact transcripts and CSV extracts to
`reports/fyp/experiments/FYP-EXP-001/`. Do not write generated files to
OneDrive. Do not label a row `reproduced_fyp_measurement` unless its compact log
and commit provenance are present.

## Expensive commands excluded from this plan

- `scripts/run_vivado_impl_dot4acc_stage_h13b_timingopt_t2.tcl` performs a
  physical implementation and is not run for this task.
- Five-run 93 MHz timing-boundary reproduction is a later, explicitly approved
  physical-validation activity.
