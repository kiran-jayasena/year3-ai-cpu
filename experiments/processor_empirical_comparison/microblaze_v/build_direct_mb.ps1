$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$gcc = 'C:\AMDDesignTools\2026.1\Vivado\gnu\riscv\nt\bin\riscv64-unknown-elf-gcc.exe'
$objcopy = 'C:\AMDDesignTools\2026.1\Vivado\gnu\riscv\nt\bin\riscv64-unknown-elf-objcopy.exe'
$objdump = 'C:\AMDDesignTools\2026.1\Vivado\gnu\riscv\nt\bin\riscv64-unknown-elf-objdump.exe'
$size = 'C:\AMDDesignTools\2026.1\Vivado\gnu\riscv\nt\bin\riscv64-unknown-elf-size.exe'
$python = 'C:\AMDDesignTools\2026.1\tps\win64\python-3.13.0\python.exe'
foreach($tool in @($gcc,$objcopy,$objdump,$size,$python)){ if(-not (Test-Path -LiteralPath $tool)){ throw "Missing tool: $tool" } }
Set-Location (Join-Path $root 'software')
& $gcc '-march=rv32im_zicsr' '-mabi=ilp32' '-O2' '-ffreestanding' '-fno-builtin' '-nostdlib' '-nostartfiles' '-nodefaultlibs' '-Wl,--build-id=none' '-Wl,-T,link.ld' '-Wl,-Map,dotprod.map' '-o' 'dotprod.elf' 'start.S' 'dotprod.c' 2>&1 | Tee-Object -FilePath (Join-Path $root 'build_direct_mb.log')
if($LASTEXITCODE -ne 0){ throw "Direct RISC-V build failed: $LASTEXITCODE" }
& $objcopy -O binary dotprod.elf dotprod.bin
& $objdump -d dotprod.elf | Tee-Object -FilePath (Join-Path $root 'dotprod.dis')
& $size dotprod.elf | Tee-Object -FilePath (Join-Path $root 'dotprod.size')
& $python (Join-Path $root 'software\make_coe.py')
