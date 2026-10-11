$ErrorActionPreference = 'Stop'
$env:XILINX_LOCAL_USER_DATA = 'no'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
& xsdb -eval "source generate_bsp.tcl" 2>&1 | Tee-Object -FilePath (Join-Path $root 'generate_bsp.log')
if ($LASTEXITCODE -ne 0) { throw "HSI BSP generation failed: $LASTEXITCODE" }
