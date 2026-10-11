$ErrorActionPreference = 'Stop'
$env:XILINX_LOCAL_USER_DATA = 'no'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
& 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat' -mode batch -nolog -nojournal -notrace -source (Join-Path $root 'pico_synth.tcl') 2>&1 | Tee-Object (Join-Path $root 'pico_synth.log')
if($LASTEXITCODE -ne 0){ throw "Pico synthesis failed: $LASTEXITCODE" }
