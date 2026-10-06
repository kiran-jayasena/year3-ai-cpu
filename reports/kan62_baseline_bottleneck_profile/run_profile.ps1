$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repoRoot
$sources = @(
    "rtl/cpu_defs_pkg.sv",
    "rtl/bram_instr_mem.sv",
    "rtl/bram_data_mem.sv",
    "rtl/dot4acc_pipeline.sv",
    "rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv",
    "reports/kan62_baseline_bottleneck_profile/tb_kan62_profile.sv"
)
& "C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat" -sv $sources
if ($LASTEXITCODE -ne 0) { throw "xvlog failed" }
& "C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat" tb_kan62_profile -s tb_kan62_profile_sim
if ($LASTEXITCODE -ne 0) { throw "xelab failed" }
& "C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat" tb_kan62_profile_sim -runall 2>&1 | Tee-Object reports/kan62_baseline_bottleneck_profile/xsim_profile.log
if ($LASTEXITCODE -ne 0) { throw "xsim failed" }
