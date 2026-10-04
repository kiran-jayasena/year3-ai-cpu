# KAN-45 clean-clone regression summary

## Test executed

The H1.3b-T2 focused architectural testbench was compiled and run entirely from the separate clean clone:

`tb/tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`

Sources were limited to tracked files in the clean clone: `cpu_defs_pkg`, `dot4acc_reference_pkg`, BRAM modules, `dot4acc_pipeline`, the H1.3b-T2 core, and the testbench.

## Result

- Stage D checks: **4,254**
- Failures: **0**
- Result: **PASS**
- Transcript: `baseline_regression.log`

The result matches the documented H1.3b-T2/KAN-46 baseline expectation of 4,254 checks and zero failures. The larger historical KAN-46 aggregate log contains multiple CPU variants; this clean-clone run is the focused H1.3b-T2 test and is the directly comparable result.

No synthesis, implementation, timing, bitstream, or hardware flow was run for KAN-45.
