$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$gcc = 'C:\AMDDesignTools\2026.1\Vivado\gnu\riscv\nt\bin\riscv64-unknown-elf-gcc.exe'
$objcopy = 'C:\AMDDesignTools\2026.1\Vivado\gnu\riscv\nt\bin\riscv64-unknown-elf-objcopy.exe'
foreach($tool in @($gcc,$objcopy)){ if(-not (Test-Path -LiteralPath $tool)){ throw "Missing tool: $tool" } }
$source = Join-Path $root '..\microblaze_v\software\dotprod.c'
Set-Location $root
& $gcc '-march=rv32im_zicsr' '-mabi=ilp32' '-O2' '-ffreestanding' '-fno-builtin' '-nostdlib' '-nostartfiles' '-nodefaultlibs' '-Wl,--build-id=none' '-Wl,-T,pico_link.ld' '-Wl,-Map,pico.map' '-o' 'pico.elf' 'pico_start.S' $source 2>&1 | Tee-Object -FilePath (Join-Path $root 'build_pico.log')
if($LASTEXITCODE -ne 0){ throw "Pico software build failed: $LASTEXITCODE" }
& $objcopy '-O' 'verilog' '--verilog-data-width=4' 'pico.elf' 'pico.mem'
& $objcopy '-O' 'binary' 'pico.elf' 'pico.bin'
& 'C:\AMDDesignTools\2026.1\tps\win64\python-3.13.0\python.exe' (Join-Path $root 'make_pico_mem.py')
