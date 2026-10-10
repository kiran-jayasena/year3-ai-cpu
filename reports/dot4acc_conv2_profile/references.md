# Sources for the DOT4ACC Conv2 measurement

All sources below are version-controlled repository files inspected directly; no external citation is needed for the measured result.

1. [ISA definition](../../docs/isa.md) — instruction format, MAC8 and DOT4ACC semantics.
2. [CPU definitions](../../rtl/cpu_defs_pkg.sv) — opcode constants and decode classifications.
3. [DOT4ACC datapath](../../rtl/dot4acc_pipeline.sv) — signed lanes, reduction widths, DSP directives, and pipeline stages.
4. [Active CPU core](../../rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv) — issue, forwarding, hazards, retirement, and performance counters.
5. [DOT reference test](../../tb/dot4acc_reference.sv) — signed packed-lane functional reference.
6. [DOT benchmark test](../../tb/tb_dot4acc_stage_h13b_timingopt_t2_benchmark.sv) — existing specialised-path verification precedent.
7. [New reproducible profile harness](tb_dot4acc_conv2_profile.sv) — exact Conv2 functional and profiling measurement.
