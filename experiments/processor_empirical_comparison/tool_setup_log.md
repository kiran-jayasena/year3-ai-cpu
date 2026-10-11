# Tool setup log

## 2026-10-11 audit

1. Inspected the existing benchmark directory and preserved its generated assets.
2. Ran `run_preflight.ps1` with PowerShell 5.1. The five data/program-fit checks passed; all Vivado, simulator, RISC-V GCC and MicroBlaze compiler checks failed because the commands were unavailable.
3. Used the explicit local Python 3.14 executable to independently evaluate both canonical CSV workloads. N=16 produced `-106` (`0xFFFFFF96`); N=128 produced `576` (`0x00000240`).
4. Checked likely AMD/Xilinx installation roots and found no Vivado/Vitis executables.
5. Did not install packages, modify system PATH, alter license settings, clone upstream cores, or modify RTL.

## Blocked branches

### Custom CPU/XSim

Blocked before RTL execution: `xvlog`, `xelab` and `xsim` are unavailable. The prepared `tb_custom_scalar_comparison.sv` was not run, so no new custom scalar cycle/counter values are claimed.

### PicoRV32

Blocked before integration: no RISC-V bare-metal GCC and no RTL simulator are installed. No upstream checkout was created because it would not produce a runnable measurement without those tools. The branch remains an architectural reference and a ready next step once the toolchain is installed.

### MicroBlaze V

Blocked before integration: Vivado, Vitis/XSCT and `mb-gcc` are unavailable. IP creation, BSP generation and deterministic measurement could not be attempted. No license or installation changes were made.

### Synthesis

Blocked: Vivado is unavailable. No LUT, FF, DSP, BRAM, WNS or Fmax result was generated in this run.

## Manual next step

On a licensed machine with Vivado 2026.1/Vitis and a RISC-V bare-metal GCC toolchain installed, source the vendor settings, rerun `run_preflight.ps1`, then execute the prepared custom testbench before attempting the external wrappers. Keep the same device, 93 MHz target, local BRAM assumptions and `-O2` flags. This is a bounded continuation, not permission to redesign the CPU.

## Follow-up: custom XSim completed

The AMD tool environment is now available. `run_custom_xsim.ps1` was run
successfully twice (the final clean run is the authoritative one):

- `xvlog` compiled all required RTL and the testbench for N=16 and N=128;
- `xelab` produced `custom_scalar_n16` and `custom_scalar_n128` snapshots;
- `xsim -runall` passed both exact golden checks;
- structured results were written to `custom_cpu/custom_xsim_results.csv` and
  `custom_cpu/custom_xsim_results.json`.

The first successful compile/run also exposed and resolved two experiment-only
generator errors: STORE field placement and numeric negative-immediate label
handling. No RTL source was changed. PicoRV32 and MicroBlaze V remain
intentionally unstarted pending review of this custom result.

## Follow-up: bounded MicroBlaze V attempt

The installed IP was confirmed from the vendor tree:
`C:\AMDDesignTools\2026.1\data\ip\xilinx\microblaze_riscv_v1_0`.
Its metadata identifies `xilinx.com:ip:microblaze_riscv:1.0` and exposes local
LMB, multiply/divide, cache and custom-instruction configuration parameters.

The experiment-local Vivado query attempted both an in-memory project and an
explicit project under `microblaze_v/vivado_query`. Both failed during
Vivado's project/application initialization with repeated
`[Common 17-354] Could not open 'C' for writing` errors. A short-path `subst`
attempt was denied by the environment. Since no block design could be created,
no BSP, benchmark binary, cycle measurement or synthesis was fabricated. The
branch was stopped under the bounded-task rule. PicoRV32 was not started,
because MicroBlaze V did not succeed and the requested sequence makes it the
next branch only after success.
