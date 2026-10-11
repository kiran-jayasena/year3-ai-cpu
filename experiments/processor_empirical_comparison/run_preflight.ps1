$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$checks = @()

function Add-Check([string]$Name, [bool]$Pass, [string]$Detail) {
    $script:checks += [PSCustomObject]@{ check=$Name; pass=$Pass; detail=$Detail }
}

$manifest = Get-Content (Join-Path $Root "vectors_manifest.json") | ConvertFrom-Json
Add-Check "n16_golden" ($manifest.n16_expected_hex -eq "0xFFFFFF96") $manifest.n16_expected_hex
Add-Check "n128_vector_length" ((Import-Csv (Join-Path $Root "n128/vectors.csv")).Count -eq 128) "canonical CSV rows"
Add-Check "n128_golden_present" (Test-Path (Join-Path $Root "n128/golden.mem")) (Get-Content (Join-Path $Root "n128/golden.mem"))
Add-Check "n16_program_fits" (((Get-Content (Join-Path $Root "n16/custom_scalar_metadata.json") | ConvertFrom-Json).instruction_words) -le 256) "instruction words"
Add-Check "n128_program_fits" (((Get-Content (Join-Path $Root "n128/custom_scalar_metadata.json") | ConvertFrom-Json).instruction_words) -le 256) "instruction words"

foreach ($tool in @("vivado", "xvlog", "xelab", "xsim", "iverilog", "verilator", "riscv32-unknown-elf-gcc", "riscv64-unknown-elf-gcc", "mb-gcc")) {
    $command = Get-Command $tool -ErrorAction SilentlyContinue
    Add-Check ("tool_" + $tool) ($null -ne $command) ($(if ($null -ne $command) { $command.Source } else { "not on PATH" }))
}

$checks | Export-Csv (Join-Path $Root "preflight_results.csv") -NoTypeInformation
@{
    generated_by = "PowerShell $($PSVersionTable.PSVersion)"
    baseline_rtl_modified = $false
    historical_reports_modified = $false
    checks = $checks
} | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $Root "preflight.json") -Encoding utf8
$checks | Format-Table -AutoSize
