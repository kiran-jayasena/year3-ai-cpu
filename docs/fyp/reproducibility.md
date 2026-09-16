# FYP Reproducibility

The summer project's reproduction notes remain available at
[`../reproducibility.md`](../reproducibility.md). They describe the frozen
summer design and retained evidence. This document governs **FYP experimental
reproducibility** and does not reclassify summer results as new work.

## Traceability rule

Every result must be traceable to:

- experiment ID;
- Git commit SHA;
- benchmark;
- FPGA part;
- Vivado version;
- clock target; and
- report files.

Record quantitative results in `data/fyp_results.csv` and place compact report
evidence under `reports/fyp/experiments/<experiment-id>/`.

## Frozen baseline regression

The repository contains a documented Vivado XSim regression runner:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1
```

It resolves `xvlog`, `xelab` and `xsim`, compiles the listed self-checking
testbenches, and fails when a compile/simulation error or failure marker is
found. The setup task did not run this potentially lengthy suite. A focused
final-architecture functional validation should be selected and recorded before
the first architectural experiment if the full historic suite is not required.

## Frozen H1.3b-T2 physical baseline

Implementation script:

`scripts/run_vivado_impl_dot4acc_stage_h13b_timingopt_t2.tcl`

Representative 93 MHz command for one isolated run:

```powershell
& 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat' -mode batch `
  -source scripts/run_vivado_impl_dot4acc_stage_h13b_timingopt_t2.tcl `
  -tclargs 10.752688172 93 1 reports/fyp/baseline/t2_93mhz_run1 fyp_baseline_t2_93mhz_run1
```

Use five separate output directories and repetition values 1 through 5 to
repeat the published boundary validation. Generated implementation directories
must remain in the local repository and must not be copied wholesale to
OneDrive. Export only compact timing/utilisation evidence.

Expected prior-work evidence at 93 MHz:

- PASS 5/5
- setup WNS `+0.230 ns`
- TNS `0 ns`
- hold WNS `+0.059 ns`
- 0 setup failures
- 2008 LUT, 1812 FF, 2 RAMB18, 5 DSP48, 1 BUFG

The nearest tested higher frequency was 94 MHz and failed timing. These values
are prior-work expectations until independently reproduced for the FYP.
