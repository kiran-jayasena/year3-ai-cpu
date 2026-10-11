$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$vivadoBin = 'C:\AMDDesignTools\2026.1\Vivado\bin'
Set-Location $root
Remove-Item -Recurse -Force xsim_work -ErrorAction SilentlyContinue
New-Item -ItemType Directory xsim_work | Out-Null
& (Join-Path $vivadoBin 'xvlog.bat') '-sv' '-work' 'xsim_work' (Join-Path $root '..\picorv32_upstream\picorv32.v') (Join-Path $root 'tb_pico_dotprod.sv') 2>&1 | Tee-Object compile.log
if($LASTEXITCODE -ne 0){ throw "xvlog failed: $LASTEXITCODE" }
& (Join-Path $vivadoBin 'xelab.bat') 'xsim_work.tb_pico_dotprod' '-debug' 'typical' '-s' 'pico_sim' '-L' 'xsim_work' '-L' 'unisim' '-L' 'xpm' '-log' 'xelab.log' 2>&1 | Tee-Object elaborate.log
if($LASTEXITCODE -ne 0){ throw "xelab failed: $LASTEXITCODE" }
& (Join-Path $vivadoBin 'xsim.bat') 'pico_sim' '-runall' '-log' 'xsim.log' 2>&1 | Tee-Object run.log
if($LASTEXITCODE -ne 0){ throw "xsim failed: $LASTEXITCODE" }
