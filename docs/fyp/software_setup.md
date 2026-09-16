# Software and Hardware Setup

## Intended toolchain

- Windows
- PowerShell
- SystemVerilog
- AMD Vivado 2026.1
- Vivado XSim
- Python
- Git
- GitHub
- Tcl

## FPGA target

- Board: Digilent Basys 3
- Part: `xc7a35tcpg236-1`

## Storage layout

- Active working repository: `C:\FPGA\year3-ai-cpu`
- Synced project/admin/evidence folder:
  `C:\Users\kiran\OneDrive - University of Southampton\Year 3 Project`

Vivado and XSim generated outputs must remain outside OneDrive. The local Git
working tree avoids sync conflicts and unnecessary storage caused by `.git`,
`.Xil`, simulation snapshots, caches and implementation runs. Only compact,
curated evidence should be exported to OneDrive.

## Useful version commands

```powershell
git --version
python --version
& 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat' -version
```

Run `scripts/fyp/capture_environment.ps1` from the repository root to record
the environment associated with an experiment.
