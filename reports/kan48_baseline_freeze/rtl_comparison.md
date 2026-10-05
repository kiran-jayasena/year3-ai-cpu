# KAN-48 RTL comparison

## References

- Inherited reference: `2731a7820988863829c7074acd474ea06902e8f2`
- Candidate pre-freeze HEAD: `8eef377277c808cc48e15fd8d2f86ef1f218277a`
- Candidate CPU: `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`

## Files compared

The following processor-defining files were compared with `git diff` against the inherited reference:

- `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- `rtl/fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- `rtl/cpu_defs_pkg.sv`
- `rtl/instruction_decoder.sv`
- `rtl/control_unit.sv`
- `rtl/bram_instr_mem.sv`
- `rtl/bram_data_mem.sv`

The comparison produced no differences. Therefore there are no candidate-revision changes to CPU functionality, ISA/decode, pipeline behaviour, memory behaviour, or wrapper interface in the files defining this baseline.

Changes after the inherited reference are limited to Year III verification, scripts, benchmark images, documentation and evidence. No MAC8/DOT4ACC acceleration change was introduced by Year III in this baseline freeze.

