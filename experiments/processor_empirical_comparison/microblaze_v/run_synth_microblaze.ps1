$ErrorActionPreference = 'Stop'
$env:XILINX_LOCAL_USER_DATA = 'no'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
& 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat' -mode batch -nolog -nojournal -notrace -source (Join-Path $root 'synth_microblaze.tcl') 2>&1 | Tee-Object -FilePath (Join-Path $root 'synth_microblaze.log')
if($LASTEXITCODE -ne 0){ throw "MicroBlaze synthesis failed: $LASTEXITCODE" }
