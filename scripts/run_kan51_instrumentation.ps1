$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot
$reportDir = Join-Path $repoRoot "reports\kan51_instrumentation"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

function Resolve-VivadoTool([string] $toolName) {
    $command = Get-Command $toolName -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    $roots = @()
    if ($env:VIVADO_BIN) { $roots += $env:VIVADO_BIN }
    if ($env:XILINX_VIVADO) { $roots += (Join-Path $env:XILINX_VIVADO "bin") }
    $roots += "C:\AMDDesignTools\2026.1\Vivado\bin"
    $roots += "C:\Xilinx\Vivado\2026.1\bin"
    foreach ($root in $roots) {
        foreach ($suffix in @(".bat", ".exe")) {
            $candidate = Join-Path $root ($toolName + $suffix)
            if (Test-Path $candidate) { return $candidate }
        }
    }
    throw "Could not find $toolName. Use a Vivado-enabled PowerShell or set VIVADO_BIN."
}

$xvlog = Resolve-VivadoTool "xvlog"
$xelab = Resolve-VivadoTool "xelab"
$xsim = Resolve-VivadoTool "xsim"
$sources = @(
    "rtl/cpu_defs_pkg.sv",
    "rtl/bram_instr_mem.sv",
    "rtl/bram_data_mem.sv",
    "rtl/dot4acc_pipeline.sv",
    "rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv",
    "tb/tb_kan51_instrumentation_validation.sv"
)
$snapshot = "tb_kan51_instrumentation_validation_sim"

& $xvlog -sv $sources
if ($LASTEXITCODE -ne 0) { throw "xvlog failed" }
& $xelab tb_kan51_instrumentation_validation -s $snapshot
if ($LASTEXITCODE -ne 0) { throw "xelab failed" }

for ($run = 1; $run -le 2; $run++) {
    $rawPath = Join-Path $reportDir "raw_repeated_runs.csv"
    if (Test-Path $rawPath) { Remove-Item -LiteralPath $rawPath -Force }
    $output = & $xsim $snapshot -runall 2>&1
    $output | Set-Content -LiteralPath (Join-Path $reportDir ("xsim_run{0}.log" -f $run))
    if ($LASTEXITCODE -ne 0) { throw "xsim failed on repetition $run" }
    if (($output -join "`n") -match "FATAL_ERROR|KAN-51 instrumentation validation failed") {
        throw "XSim reported a validation failure on repetition $run"
    }
    if (-not (Test-Path $rawPath)) { throw "XSim did not produce $rawPath" }
    Copy-Item -LiteralPath $rawPath -Destination (Join-Path $reportDir ("raw_repeated_runs_run{0}.csv" -f $run)) -Force
}

& python scripts\summarize_kan51_instrumentation.py
if ($LASTEXITCODE -ne 0) { throw "KAN-51 result summariser failed" }
Write-Host "KAN-51 instrumentation validation completed."
