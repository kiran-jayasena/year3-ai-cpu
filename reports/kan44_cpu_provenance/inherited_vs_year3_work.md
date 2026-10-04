# Inherited work versus Year III work

| Item | Status | Evidence | Year III classification |
|---|---|---|---|
| H1.3b-T2 CPU pipeline RTL | Introduced in `b90a3dca` before the Year III marker | `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`; `git log --follow` | Pre-existing |
| H1.3b-T2 FPGA wrapper | Introduced in `b90a3dca` | `rtl/fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv` | Pre-existing |
| Base ISA and instruction encoding | Historical project architecture | `docs/isa.md`, `rtl/cpu_defs_pkg.sv` | Pre-existing |
| MAC8/DOT4ACC extensions | Historical AI/CPU experiments | `docs/isa.md`, historical Stage H/L reports | Pre-existing |
| H1.3b-T2 architectural testbench | Added with candidate revision | `tb/tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv` | Pre-existing |
| Stage H timing/resource evidence | Historical summer-project evidence | `reports/dot4acc_stage_h/`, `reports/dot4acc_stage_h_memory_feed.md` | Pre-existing |
| `fyp-baseline` repository marker | Added as a Year III baseline marker around inherited work | annotated tag `fyp-baseline` -> `2731a782` | Boundary marker |
| KAN-349 MNIST desktop reference | Created on Year III branch | `software/ai_reference/` | Year III |
| KAN-350 scalar C reference | Created on Year III branch | `software/ai_reference/c_reference/` | Year III |
| KAN-50 representative Conv2 benchmark | Created on Year III branch | `programs/kan50_conv2_tile.mem`, `tb/tb_kan50_processor_benchmark.sv`, `reports/kan50_processor_benchmark/` | Year III |
| KAN-51 instrumentation validation | Created on Year III branch | `tb/tb_kan51_instrumentation_validation.sv`, `reports/kan51_instrumentation/` | Year III |
| Future S4 profiling and acceleration | Not implemented in this record | Future project tasks | Future Year III |

