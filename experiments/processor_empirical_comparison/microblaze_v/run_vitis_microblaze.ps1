$ErrorActionPreference = 'Stop'
$env:XILINX_LOCAL_USER_DATA = 'no'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$vitis = 'C:\AMDDesignTools\2026.1\Vitis\bin\vitis.bat'
$python = 'C:\AMDDesignTools\2026.1\tps\win64\python-3.13.0\python.exe'
if (-not (Test-Path -LiteralPath $vitis)) { throw "Vitis not found: $vitis" }
if (-not (Test-Path -LiteralPath $python)) { throw "Python not found: $python" }
Set-Location $root
& $python (Join-Path $root 'generate_benchmark.py') 2>&1 | Tee-Object -FilePath (Join-Path $root 'generate_benchmark.log')
if ($LASTEXITCODE -ne 0) { throw "Benchmark generation failed: $LASTEXITCODE" }
& $vitis -s (Join-Path $root 'build_vitis.py') 2>&1 | Tee-Object -FilePath (Join-Path $root 'build_vitis.log')
if ($LASTEXITCODE -ne 0) { throw "Vitis build failed: $LASTEXITCODE" }
