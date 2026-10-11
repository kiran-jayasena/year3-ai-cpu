$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repoRoot
$vivado = "C:\AMDDesignTools\2026.1\Vivado\bin"
$sources = @(
  "rtl/cpu_defs_pkg.sv",
  "rtl/bram_instr_mem.sv",
  "rtl/bram_data_mem.sv",
  "rtl/dot4acc_pipeline.sv",
  "rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv",
  "reports/dot4acc_microbench/tb_dot4acc_microbench.sv"
)
& (Join-Path $vivado "xvlog.bat") -sv $sources 2>&1 | Tee-Object reports/dot4acc_microbench/xvlog.log
if ($LASTEXITCODE -ne 0) { throw "xvlog failed" }
& (Join-Path $vivado "xelab.bat") tb_dot4acc_microbench -s tb_dot4acc_microbench_sim 2>&1 | Tee-Object reports/dot4acc_microbench/xelab.log
if ($LASTEXITCODE -ne 0) { throw "xelab failed" }
& (Join-Path $vivado "xsim.bat") tb_dot4acc_microbench_sim -runall 2>&1 | Tee-Object reports/dot4acc_microbench/xsim.log
if ($LASTEXITCODE -ne 0) { throw "xsim failed" }
