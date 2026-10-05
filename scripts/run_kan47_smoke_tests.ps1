$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot
$reportDir = Join-Path $repoRoot "reports\kan47_smoke_tests"
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

$xvlog = Resolve-VivadoTool "xvlog"
$xelab = Resolve-VivadoTool "xelab"
$xsim = Resolve-VivadoTool "xsim"
$sources = @(
    "rtl/cpu_defs_pkg.sv",
    "rtl/bram_instr_mem.sv",
    "rtl/bram_data_mem.sv",
    "rtl/dot4acc_pipeline.sv",
    "rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv",
    "tb/tb_kan47_smoke_tests.sv"
)

& $xvlog -sv $sources 2>&1 | Set-Content (Join-Path $reportDir "xvlog.log")
if ($LASTEXITCODE -ne 0) { throw "xvlog failed" }
& $xelab tb_kan47_smoke_tests -s tb_kan47_smoke_tests_sim 2>&1 | Set-Content (Join-Path $reportDir "xelab.log")
if ($LASTEXITCODE -ne 0) { throw "xelab failed" }
$output = & $xsim tb_kan47_smoke_tests_sim -runall 2>&1
$output | Set-Content (Join-Path $reportDir "xsim.log")
if ($LASTEXITCODE -ne 0) { throw "xsim failed" }
if (($output -join "`n") -match "FATAL_ERROR|KAN-47 smoke tests FAILED") { throw "KAN-47 smoke tests reported failure" }
if (-not (Test-Path (Join-Path $reportDir "repeated_runs.csv"))) { throw "missing repeated_runs.csv" }

python scripts\summarize_kan47_smoke_tests.py
if ($LASTEXITCODE -ne 0) { throw "KAN-47 summary verification failed" }
Write-Host "KAN-47 smoke tests completed."
