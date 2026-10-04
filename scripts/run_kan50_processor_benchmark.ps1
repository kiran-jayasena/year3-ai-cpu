$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot
$reportDir = Join-Path $repoRoot "reports\kan50_processor_benchmark"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null

function Resolve-VivadoTool([string] $toolName) {
    $command = Get-Command $toolName -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    foreach ($root in @("C:\AMDDesignTools\2026.1\Vivado\bin", "C:\Xilinx\Vivado\2026.1\bin")) {
        foreach ($suffix in @(".bat", ".exe")) {
            $candidate = Join-Path $root ($toolName + $suffix)
            if (Test-Path $candidate) { return $candidate }
        }
    }
    throw "Could not find $toolName"
}

python software\ai_reference\tools\generate_kan50_conv2_tile.py | Set-Content (Join-Path $reportDir "generation.log")
if ($LASTEXITCODE -ne 0) { throw "benchmark data generation failed" }

$vivadoSources = @(
    "rtl/cpu_defs_pkg.sv",
    "rtl/bram_instr_mem.sv",
    "rtl/bram_data_mem.sv",
    "rtl/dot4acc_pipeline.sv",
    "rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv",
    "tb/tb_kan50_processor_benchmark.sv"
)
$xvlog = Resolve-VivadoTool "xvlog"
$xelab = Resolve-VivadoTool "xelab"
$xsim = Resolve-VivadoTool "xsim"
$snapshot = "tb_kan50_processor_benchmark_sim"

& $xvlog -sv $vivadoSources
if ($LASTEXITCODE -ne 0) { throw "xvlog failed" }
& $xelab tb_kan50_processor_benchmark -s $snapshot
if ($LASTEXITCODE -ne 0) { throw "xelab failed" }

for ($run = 1; $run -le 2; $run++) {
    $raw = Join-Path $reportDir "repeated_runs.csv"
    if (Test-Path $raw) { Remove-Item -LiteralPath $raw -Force }
    $output = & $xsim $snapshot -runall 2>&1
    $output | Set-Content (Join-Path $reportDir ("xsim_run{0}.log" -f $run))
    if ($LASTEXITCODE -ne 0) { throw "xsim failed on repetition $run" }
    if (($output -join "`n") -match "FATAL_ERROR|KAN-50 representative benchmark failed") {
        throw "XSim reported a benchmark failure on repetition $run"
    }
    if (-not (Test-Path $raw)) { throw "XSim did not produce repeated_runs.csv" }
    Copy-Item $raw (Join-Path $reportDir ("repeated_runs_run{0}.csv" -f $run)) -Force
}

python scripts\summarize_kan50_processor_benchmark.py
if ($LASTEXITCODE -ne 0) { throw "benchmark result verification failed" }
Write-Host "KAN-50 representative processor benchmark completed."
