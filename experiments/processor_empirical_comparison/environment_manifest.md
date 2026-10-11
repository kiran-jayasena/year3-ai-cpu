# Local environment manifest

Audit date: 2026-10-11  
Working directory: `C:\FPGA\year3-ai-cpu`  
Shell: Windows PowerShell 5.1.26100.9444  
Host OS: Windows 11, build 26200 (reported in the successful XSim session log)

## Available tools

| Tool | Result | Path/version |
|---|---|---|
| Git | available | `C:\Program Files\Git\cmd\git.exe`, 2.55.0.windows.1 |
| MinGW GCC | available but not relevant to the target CPUs | `C:\MinGW\bin\gcc.exe`, 6.3.0 |
| GNU make | available | `C:\MinGW\msys\1.0\bin\make.exe`, 3.81 |
| Python | available outside the normal PATH alias | `C:\Users\kiran\AppData\Local\Python\pythoncore-3.14-64\python.exe`, 3.14.0 |
| Python alternate | available outside the normal PATH alias | `C:\Users\kiran\AppData\Local\AnkiProgramFiles\python\cpython-3.13.5-windows-x86_64-none\python.exe`, 3.13.5 |

The `python` and `python3` PATH entries resolve to Microsoft Store aliases. The explicit Python 3.14 path above was used for the independent vector/golden-result check.

## Required tools not available

The following commands were absent from PATH and no executable was found in the checked AMD/Xilinx installation roots (`C:\Xilinx`, `C:\AMD`, `C:\Program Files\Xilinx`, `C:\Program Files\AMD`, and their x86 equivalents):

- Vivado, `xvlog`, `xelab`, `xsim`;
- Vitis, XSCT, and `mb-gcc`;
- MicroBlaze V IP discovery through Vivado;
- `riscv32-unknown-elf-gcc`, `riscv64-unknown-elf-gcc`, and `riscv-none-elf-gcc`;
- Verilator;
- Icarus Verilog.

`C:\intelFPGA\20.1` exists, but it is an Intel/ModelSim installation and does not provide the AMD/Xilinx Vivado/Vitis flow required by this experiment.

## PATH and environment handling

The active PATH was inspected and retained unchanged. No system-wide PATH, license variable, or installation was modified. Relevant PATH entries included Git, MinGW, MATLAB, Intel ModelSim, and WindowsApps, but no AMD/Xilinx or RISC-V toolchain directory.

Environment variables containing credentials, tokens, keys, passwords, or authentication material were not copied into this report; such values were treated as redacted during the audit. No FPGA license configuration was changed.

## Installation/configuration decision

No software was installed. Installing Vivado/Vitis would be a large licensed installation and is outside a bounded experiment without an existing installation and license. Installing a RISC-V toolchain or simulator would still leave the Vivado/MicroBlaze and custom XSim branches blocked, so it was not justified as an isolated action. The explicit local Python executable was used without changing global configuration.

## Consequence for execution

The prepared benchmark data and static correctness checks were executed. RTL cycle runs, PicoRV32 compilation/simulation, MicroBlaze V setup, and same-device synthesis were not executable on this machine because their required tools were unavailable. No performance value is inferred from the absence of a tool.

## Follow-up audit and custom XSim execution

The environment blocker was subsequently resolved. The following tools were
callable during the successful custom-CPU run:

| Tool | Path | Reported version |
|---|---|---|
| Vivado | `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat` | 2026.1 installation; `--version` is not a valid Vivado option |
| xvlog | `C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat` | Vivado Simulator 2026.1 |
| xelab | `C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat` | Vivado Simulator 2026.1 |
| xsim | `C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat` | Vivado Simulator 2026.1 |
| Vitis | `C:\AMDDesignTools\2026.1\Vitis\bin\vitis.bat` | 2026.1 environment |
| xsdb | `C:\AMDDesignTools\2026.1\Vivado\bin\xsdb.bat` | callable |
| mb-gcc | `C:\AMDDesignTools\2026.1\gnu\microblaze\nt\bin\mb-gcc.exe` | GCC 13.4.0 |
| mb-objdump/objcopy/size | same MicroBlaze bin directory | Binutils 2.35.1 |
| mb-ld | same MicroBlaze bin directory | GNU ld 2.42.0.20240723 |

The experiment-local runner `run_custom_xsim.ps1` compiled the frozen core,
elaborated it and ran N=16 and N=128. Both exact-output checks passed. The
structured raw outputs are in
`custom_cpu/custom_xsim_results.csv` and `.json`; the consolidated comparison
is in `results.csv`.

The current audit supersedes the earlier missing-tool conclusion for this
machine. PicoRV32 remains unattempted; MicroBlaze V remains unattempted until
the custom run is reviewed, as required by the bounded execution order.

## MicroBlaze V follow-up execution

The installed hardware flow was used without system-wide reconfiguration:

| Item | Observed value |
|---|---|
| Vivado | `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat`, 2026.1 |
| Vitis | `C:\AMDDesignTools\2026.1\Vitis\bin\vitis.bat`, 2026.1 |
| XSA | `microblaze_v/project/mb_system_fixed.xsa`, exported successfully with `write_hw_platform -fixed` |
| Part | `xc7a35tcpg236-1` |
| IP | `xilinx.com:ip:microblaze_riscv:1.0` |
| `mb-gcc` | Installed classic MicroBlaze compiler; not the compiler expected by the RISC-V IP |
| RISC-V compiler | `C:\AMDDesignTools\2026.1\Vivado\gnu\riscv\nt\bin\riscv64-unknown-elf-gcc.exe` |

The Vitis platform flow failed while generating its processor list. The HSI
standalone fallback then failed because the installed Xilinx RISC-V compiler
sysroot is named `riscv32-xilinx-elf`, while the BSP generator searched for
`riscv64-unknown-elf/lib`. A direct experiment-local bare-metal compile did
succeed, but no processor execution was claimed. The synthesis run was started
but did not complete within five minutes; no resource or timing result was
recorded.

## Final bounded follow-up status

PicoRV32 was subsequently executed using the official repository at commit
`ef203c2b0a3fb793280f5114941416c425c5b461`. The primary hardware-multiply
configuration passed exact N=16 and N=128 XSim checks. It measured 1,040 and
8,208 cycles respectively, with 115 and 899 retired instructions. The
experiment-local same-part synthesis completed with 10,006 LUTs, 869 FFs,
zero DSPs, zero BRAM tiles and 2.567 ns WNS at a 93 MHz constraint. The
reported 122.17 MHz value is a synthesis timing estimate, not a placed-and-
routed Fmax; the LUTRAM memory wrapper also prevents direct resource
comparison with the custom BRAM-backed CPU.

MicroBlaze V follow-up advanced beyond hardware generation: the fixed XSA was
exported, generated simulation sources compiled, and the direct ELF was
converted to experiment-local BRAM MIF files. However, vendor-IP elaboration
did not reach execution in bounded 180-second and 600-second XSim attempts,
and synthesis did not complete in a 600-second bounded run. No MicroBlaze
cycle, instruction, resource or Fmax result is claimed. Logs remain under
`microblaze_v/`, including `micro_xelab.log`, `micro_run.log` and
`synth_microblaze.log`.
