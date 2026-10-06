# KAN-57 Baseline Resource Utilisation

## Baseline identity

- Git tag: `fyp-stage3-baseline`
- Frozen commit: `f6b25ca196493858cc2b501a0324c4a794c0dd94`
- CPU/top: `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2` / `fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2`
- FPGA/board: `xc7a35tcpg236-1` / Digilent Basys 3
- Vivado: 2026.1, build 6511674
- Report type: post-implementation/post-route utilisation
- Report date: 2026-10-05 (from Vivado report header)

The raw report was reused from the clean KAN-55 implementation evidence because it is a routed report for the exact frozen tag and design. A hierarchical report was generated from the retained routed checkpoint on 2026-10-06; no synthesis or implementation settings were changed.

## Device utilisation

| Resource | Used | Available | Utilisation |
|---|---:|---:|---:|
| Slice LUTs | 2,008 | 20,800 | 9.65% |
| Slice registers / FFs | 1,812 | 41,600 | 4.36% |
| DSP48E1 | 5 | 90 | 5.56% |
| Block RAM tiles | 1 | 50 | 2.00% |
| RAMB18 primitives | 2 | 100* | 2.00% |
| LUTRAM / LUT as memory | 0 | 9,600 | 0.00% |
| Bonded IOBs | 19 | 106 | 17.92% |
| BUFGCTRL | 1 | 32 | 3.13% |

\* Vivado reports RAMB18 availability as 100 primitive sites; the device-level block-RAM tile count is 1/50.

## Hierarchical utilisation observations

The hierarchical report is `baseline_utilisation_hierarchical.rpt`. Its aggregate rows show:

| Instance | Module | Total LUTs | FFs | RAMB18 | DSP |
|---|---|---:|---:|---:|---:|
| `cpu_inst` (aggregate) | `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2` | 2,008 | 1,812 | 2 | 5 |
| `cpu_inst` (logic excluding children) | CPU core | 978 | 1,716 | 0 | 1 |
| `dot4acc_pipeline_inst` | `dot4acc_pipeline` | 545 | 96 | 0 | 4 |
| `data_mem_inst` | `bram_data_mem` | 329 | 0 | 1 | 0 |
| `instr_mem_inst` | `bram_instr_mem` | 171 | 0 | 1 | 0 |

The `cpu_inst` aggregate includes child instances; the parent-only row is shown separately to avoid double-counting. These are descriptive utilisation observations, not architectural bottleneck conclusions.

## Reproducibility and scope

- Source post-route report: `baseline_utilisation_post_impl.rpt`
- Hierarchical report source checkpoint: `reports/kan55_baseline_fpga_implementation/checkpoints/baseline_routed.dcp`
- No CPU RTL, ISA, constraints, memory architecture, or accelerator functionality was changed.
- No KAN-58 work or resource optimisation was performed.

