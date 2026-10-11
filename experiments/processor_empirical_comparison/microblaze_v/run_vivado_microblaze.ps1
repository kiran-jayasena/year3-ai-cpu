$ErrorActionPreference = 'Stop'
$env:XILINX_LOCAL_USER_DATA = 'no'
$Vivado = 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path -LiteralPath $Vivado)) { throw "Vivado not found at $Vivado" }
Set-Location $Root
& $Vivado -mode batch -nolog -nojournal -notrace -source (Join-Path $Root 'create_microblaze_project.tcl') 2>&1 | Tee-Object -FilePath (Join-Path $Root 'create_microblaze_project.log')
if ($LASTEXITCODE -ne 0) { throw "Vivado project generation failed with exit code $LASTEXITCODE" }
