# MicroBlaze V bounded comparison

## Hardware result

Vivado 2026.1 created and validated `project/mb_reference.xpr` for
`xc7a35tcpg236-1`. The design uses `xilinx.com:ip:microblaze_riscv:1.0`, a
three-stage area-oriented configuration (`C_OPTIMIZATION=1`), separate 32-bit
instruction/data LMBs, two 32 KiB BRAM memories, caches disabled, counters
enabled, barrel shifter enabled, no FSL/custom instruction interface, no FPU,
no compressed or atomic extension, and `C_USE_MULDIV=1`.

`C_USE_MULDIV` is a combined RISC-V M-extension control in this IP; it cannot
be split into multiply-on/divide-off. Therefore the actual design has the
standard hardware multiply/divide option enabled. This is recorded as a
configuration limitation, not silently described as divider-disabled.

The validated hardware platform is `project/mb_system_fixed.xsa`. The
successful export required `write_hw_platform -fixed`; the original non-fixed
export produced `[Project 1-1040] Failed to get Source File object for dynamic
region BD`.

## Software result and blocker

Vitis platform creation was attempted with `build_vitis.py`. It stopped at:

`Failed to create platform: mb_platform. Error in generating Processor List.`

The experiment-local HSI fallback reached standalone BSP generation but stopped
with:

`Couldn't figure out compiler's library directory: tried
C:/AMDDesignTools/2026.1/Vivado/gnu/riscv/nt/riscv64-unknown-elf/lib`

The installation actually contains the Xilinx RISC-V sysroot under
`riscv32-xilinx-elf`, so no Vitis BSP or cycle measurement is claimed.

As a bounded software compatibility check, `build_direct_mb.ps1` compiled the
exact generated N=16/N=128 source at `-O2` using the installed RISC-V compiler,
with `-march=rv32im_zicsr -mabi=ilp32`, an experiment-local startup file and
linker script. The ELF is valid RV32IM and its disassembly contains `mul`,
`rdcycle` and `rdinstret`. This is a build result only, not an executed
MicroBlaze measurement.

The Vivado synthesis attempt was also started with the same target and a
93 MHz clock constraint. After generated targets were available it was given
a bounded 600-second execution window, but did not finish. No utilization,
WNS or Fmax value is reported.

## Direct simulation follow-up

The experiment-local direct ELF was rebuilt with `--build-id=none`, verified
to start at address `0x00000000`, and converted to `imem.mif`/`dmem.mif`.
Generated simulation wrappers were copied into `sim_sources` and patched
there only to enable the memory initialization files; generated project
sources were not modified. VHDL/SystemVerilog compilation succeeded and
vendor-IP elaboration was attempted for 180 seconds and then 600 seconds,
but neither run reached benchmark execution. The logs are
`micro_xvlog.log`, `micro_xelab.log`, `micro_run.log` and
`configure_sim_mem2.log`.

All commands preserve `XILINX_LOCAL_USER_DATA=no`. No custom CPU RTL or
historical benchmark evidence was modified.
