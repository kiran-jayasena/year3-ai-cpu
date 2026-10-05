# KAN-55 Baseline FPGA Synthesis and Implementation

## Objective

Demonstrate that the frozen Stage 3 experimental baseline can be synthesised and implemented on the Basys 3 target using the established Vivado flow. This is a reproducibility/evidence run only; no timing optimisation, constraint change, RTL change, ISA change, or acceleration was introduced.

## Baseline identity

- Tag: `fyp-stage3-baseline`
- Commit: `f6b25ca196493858cc2b501a0324c4a794c0dd94`
- CPU: `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2`
- FPGA: `xc7a35tcpg236-1` (Digilent Basys 3)
- Isolated workspace: `C:\FPGA\kan55-baseline-impl`
- Workspace state: detached HEAD at the exact frozen commit; no source changes were made for the run.

## Tool environment

- Windows 11 Pro, build 26200
- PowerShell 5.1.26100.9444
- Git 2.55.0.windows.1
- AMD Vivado/XSim 2026.1, build 6511674

Raw environment and Git state are in `environment.txt` and `git_state.txt`.

## Existing implementation flow

The unchanged script `scripts/run_vivado_impl_dot4acc_stage_h13b_timingopt_t2.tcl` was used. It reads the CPU package, BRAMs, `rtl/dot4acc_pipeline.sv`, the H1.3b-T2 CPU RTL, the matching FPGA wrapper, and `constraints/basys3.xdc`; it applies its generated clock override and runs `synth_design`, `opt_design`, `place_design`, `route_design`, reports, checkpoint generation, and bitstream generation.

The script requires five Tcl arguments. The successful command is recorded in `commands.txt`. An initial invocation without these arguments exited before synthesis with the script's usage error; this was documented and did not alter any design files.

## Design identity

- Top module: `fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2`
- CPU RTL: `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- FPGA wrapper: `rtl/fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
- Supporting RTL: `rtl/cpu_defs_pkg.sv`, `rtl/bram_instr_mem.sv`, `rtl/bram_data_mem.sv`, `rtl/dot4acc_pipeline.sv`
- Board constraints: `constraints/basys3.xdc`
- Instruction image generic: `programs/dot4acc_stage_d.mem`
- Clock: `sys_clk_pin`, requested period 10.752688172 ns (93 MHz); applied report period 10.753 ns / 92.997 MHz

## Results

| Stage | Result |
|---|---|
| RTL read/elaboration | PASS |
| Synthesis | PASS |
| `opt_design` | PASS |
| Placement | PASS |
| Routing | PASS; 3,352/3,352 routable nets fully routed, 0 routing errors |
| DRC | Completed with 6 warnings, no reported errors |
| Routed checkpoint | PASS |
| Bitstream generation | PASS in isolated workspace |

The bitstream was generated in the isolated workspace but is not copied into the repository evidence package; the routed checkpoint and raw reports are retained.

## Raw timing results

From the post-route timing summary:

- Clock: `sys_clk_pin`, 10.753 ns, 92.997 MHz
- WNS: `+0.230 ns`
- TNS: `0.000 ns`
- Setup failing endpoints: `0`
- Worst hold slack (WHS): `+0.059 ns`
- Hold total violation: `0.000 ns`
- Hold failing endpoints: `0`
- Worst pulse-width slack: `+4.876 ns`

These are recorded raw implementation results. KAN-55 does not interpret them as optimisation or bottleneck conclusions.

## Raw utilisation results

From the post-route utilisation report:

- Slice LUTs: `2,008` / 20,800 (9.65%)
- Slice registers: `1,812` / 41,600 (4.36%)
- Block RAM tiles: `1` / 50 (2.00%), containing `2` RAMB18 primitives
- DSP48E1: `5` / 90 (5.56%)
- BUFG: `1` / 32 (3.13%)

## DRC and methodology notes

The DRC report contains six warnings: one Basys configuration-property warning (`CFGBVS-1`) and five DSP pipelining advisory warnings (`DPIP-1`, `DPOP-1`, `DPOP-2`). No DRC error was reported and route status is fully routed. The existing XDC and RTL were not changed to suppress these warnings.

The timing checker reports two input ports and sixteen output ports without I/O delay constraints, matching the board-level baseline flow. These are retained in the raw `drc/check_timing.rpt` evidence.

## Changes made

- CPU RTL: none
- ISA/decode/control: none
- Memory architecture: none
- Constraints: none; only the flow-generated clock override was used as prescribed by the existing script
- Synthesis/implementation strategy: unchanged (`Default`, no physical optimisation directive)
- Frozen tag/history: unchanged

## Retained evidence

- `timing/`: synthesis, post-place, post-route, setup/hold, and critical-path reports
- `utilisation/`: synthesis and post-route utilisation reports
- `drc/`: DRC, timing-check, methodology, and clock-interaction reports
- `route/post_route_status.rpt`
- `logs/vivado.log`
- `checkpoints/baseline_routed.dcp`
- `constraints/clock_override.xdc`
- `run_result.csv`

## Conclusion

The exact frozen Stage 3 baseline synthesised and implemented successfully in an isolated workspace using Vivado 2026.1. Placement and routing completed, the design was fully routed with zero routing errors, DRC completed with warnings only, and raw timing/utilisation evidence plus a routed checkpoint were preserved. The package is suitable as the physical baseline evidence for KAN-56, KAN-57, and later baseline-versus-accelerated comparisons. No KAN-56 timing optimisation, KAN-57 resource interpretation, KAN-59 power analysis, or KAN-62 bottleneck analysis was performed.

