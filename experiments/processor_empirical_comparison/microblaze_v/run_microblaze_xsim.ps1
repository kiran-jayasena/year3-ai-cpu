$ErrorActionPreference = 'Stop'
$env:XILINX_LOCAL_USER_DATA = 'no'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$vivado = 'C:\AMDDesignTools\2026.1\Vivado\bin'
Set-Location $root
& 'C:\AMDDesignTools\2026.1\tps\win64\python-3.13.0\python.exe' (Join-Path $root 'software\make_mif.py')
& 'C:\AMDDesignTools\2026.1\tps\win64\python-3.13.0\python.exe' (Join-Path $root 'make_sim_sources.py')
Copy-Item (Join-Path $root 'software\imem.mif') (Join-Path $root 'sim_sources\imem.mif') -Force
Copy-Item (Join-Path $root 'software\dmem.mif') (Join-Path $root 'sim_sources\dmem.mif') -Force
Set-Location (Join-Path $root 'sim_sources')
Remove-Item -Recurse -Force xsim_work -ErrorAction SilentlyContinue
New-Item -ItemType Directory xsim_work | Out-Null
& (Join-Path $vivado 'xvhdl.bat') '--2008' '-work' 'xsim_work' (Join-Path $root 'project\mb_reference.gen\sources_1\bd\mb_system\ip\mb_system_dlmb_bram_if_cntlr_0\sim\mb_system_dlmb_bram_if_cntlr_0.vhd') (Join-Path $root 'project\mb_reference.gen\sources_1\bd\mb_system\ip\mb_system_ilmb_bram_if_cntlr_0\sim\mb_system_ilmb_bram_if_cntlr_0.vhd') (Join-Path $root 'project\mb_reference.gen\sources_1\bd\mb_system\ip\mb_system_microblaze_0_0\sim\mb_system_microblaze_0_0.vhd') (Join-Path $root 'project\mb_reference.gen\sources_1\bd\mb_system\ip\mb_system_rst_sys_0\sim\mb_system_rst_sys_0.vhd') 2>&1 | Tee-Object (Join-Path $root 'micro_xvhdl.log')
if($LASTEXITCODE -ne 0){ throw "MicroBlaze xvhdl failed: $LASTEXITCODE" }
& (Join-Path $vivado 'xvlog.bat') '-sv' '-work' 'xsim_work' (Join-Path (Get-Location) 'mb_system_ilmb_bram_0.v') (Join-Path (Get-Location) 'mb_system_dlmb_bram_0.v') (Join-Path (Get-Location) 'mb_system_interrupt_const_0.v') (Join-Path (Get-Location) 'mb_system.v') (Join-Path $root 'tb_microblaze_elf.sv') (Join-Path $root 'sim_export\mb_system\xsim\glbl.v') 2>&1 | Tee-Object (Join-Path $root 'micro_xvlog.log')
if($LASTEXITCODE -ne 0){ throw "MicroBlaze xvlog failed: $LASTEXITCODE" }
& (Join-Path $vivado 'xelab.bat') 'xsim_work.tb_microblaze_elf' 'xsim_work.glbl' '-debug' 'typical' '-s' 'micro_sim' '-L' 'xsim_work' '-L' 'microblaze_v11_0_17' '-L' 'microblaze_riscv_v1_0_9' '-L' 'lmb_bram_if_cntlr_v4_0_28' '-L' 'blk_mem_gen_v8_4_13' '-L' 'proc_sys_reset_v5_0_17' '-L' 'xlconstant_v1_1_11' '-L' 'unisims_ver' '-L' 'unimacro_ver' '-L' 'secureip' '-L' 'xpm' '-log' (Join-Path $root 'micro_xelab.log') 2>&1 | Tee-Object (Join-Path $root 'micro_elaborate.log')
if($LASTEXITCODE -ne 0){ throw "MicroBlaze xelab failed: $LASTEXITCODE" }
& (Join-Path $vivado 'xsim.bat') 'micro_sim' '-runall' '-log' (Join-Path $root 'micro_xsim.log') 2>&1 | Tee-Object (Join-Path $root 'micro_run.log')
if($LASTEXITCODE -ne 0){ throw "MicroBlaze xsim failed: $LASTEXITCODE" }
