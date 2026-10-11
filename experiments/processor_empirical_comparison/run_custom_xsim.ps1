param(
    [string]$VivadoBin = '',
    [int]$MaxCycles = 200000
)

$ErrorActionPreference = 'Stop'

$ExperimentRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ExperimentRoot '..\..')).Path
$RunRoot = Join-Path $ExperimentRoot 'custom_cpu\xsim_runs'
$ResultsCsv = Join-Path $ExperimentRoot 'custom_cpu\custom_xsim_results.csv'
$ResultsJson = Join-Path $ExperimentRoot 'custom_cpu\custom_xsim_results.json'
New-Item -ItemType Directory -Force -Path $RunRoot, (Split-Path $ResultsCsv) | Out-Null

function Resolve-Tool([string]$Name, [string]$Fallback) {
    if ($Fallback -and (Test-Path -LiteralPath $Fallback)) { return $Fallback }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { throw "Required tool '$Name' is not available. Source the Vivado 2026.1 settings first." }
    return $cmd.Source
}

if ($VivadoBin) {
    $xvlog = Join-Path $VivadoBin 'xvlog.bat'
    $xelab = Join-Path $VivadoBin 'xelab.bat'
    $xsim  = Join-Path $VivadoBin 'xsim.bat'
} else {
    $xvlog = ''
    $xelab = ''
    $xsim = ''
}
$xvlog = Resolve-Tool 'xvlog' $xvlog
$xelab = Resolve-Tool 'xelab' $xelab
$xsim = Resolve-Tool 'xsim' $xsim

$sources = @(
    (Join-Path $RepoRoot 'rtl\cpu_defs_pkg.sv'),
    (Join-Path $RepoRoot 'rtl\bram_instr_mem.sv'),
    (Join-Path $RepoRoot 'rtl\bram_data_mem.sv'),
    (Join-Path $RepoRoot 'rtl\dot4acc_pipeline.sv'),
    (Join-Path $RepoRoot 'rtl\cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv'),
    (Join-Path $ExperimentRoot 'tb_custom_scalar_comparison.sv')
)
foreach ($source in $sources) {
    if (-not (Test-Path -LiteralPath $source)) { throw "Missing source: $source" }
}

$oldLocation = Get-Location
Set-Location $RepoRoot
try {
    $allResults = @()
    foreach ($case in @(@{Name='n16'; Define='N16'; Expected='FFFFFF96'; MacCount=16}, @{Name='n128'; Define='N128'; Expected='00000240'; MacCount=128})) {
        $caseDir = Join-Path $RunRoot $case.Name
        New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
        $workLib = "custom_$($case.Name)"
        $snapshot = "custom_scalar_$($case.Name)"
        $xvlogLog = Join-Path $caseDir 'xvlog.log'
        $xelabLog = Join-Path $caseDir 'xelab.log'
        $xsimLog = Join-Path $caseDir 'xsim.log'

        Write-Host "=== $($case.Name) xvlog ==="
        & $xvlog -sv -work $workLib -d $case.Define @sources 2>&1 | Tee-Object -FilePath $xvlogLog
        if ($LASTEXITCODE -ne 0) { throw "xvlog failed for $($case.Name), exit code $LASTEXITCODE" }

        Write-Host "=== $($case.Name) xelab ==="
        & $xelab "$workLib.tb_custom_scalar_comparison" -s $snapshot -debug typical 2>&1 | Tee-Object -FilePath $xelabLog
        if ($LASTEXITCODE -ne 0) { throw "xelab failed for $($case.Name), exit code $LASTEXITCODE" }

        Write-Host "=== $($case.Name) xsim ==="
        & $xsim $snapshot -runall -log $xsimLog 2>&1 | Tee-Object -FilePath (Join-Path $caseDir 'xsim_console.log')
        if ($LASTEXITCODE -ne 0) { throw "xsim failed for $($case.Name), exit code $LASTEXITCODE" }
        if (-not (Test-Path -LiteralPath $xsimLog)) { throw "xsim did not produce $xsimLog" }

        $text = Get-Content -Raw -LiteralPath $xsimLog
        $caseMatch = [regex]::Match($text, 'CUSTOM_CASE=.*? cycles=(\d+) retired=(\d+) pass=(\d+) multiply_instructions=(\d+)')
        $counterMatch = [regex]::Match($text, 'COUNTERS loads=(\d+) stores=(\d+) branches_taken=(\d+) branches_not_taken=(\d+) jumps=(\d+) control_flush=(\d+) fetch_wait=(\d+) memory_wait=(\d+) data_hazard=(\d+) load_use=(\d+)')
        $opcodeMatch = [regex]::Match($text, 'OPCODES add=(\d+) sub=(\d+) addi=(\d+) load=(\d+) store=(\d+) beq=(\d+) jump=(\d+)')
        if (-not $caseMatch.Success -or -not $counterMatch.Success -or -not $opcodeMatch.Success) {
            throw "Could not parse structured benchmark output for $($case.Name). See $xsimLog"
        }
        if ($caseMatch.Groups[3].Value -ne '1') { throw "Golden result failed for $($case.Name)" }

        $retired = [int]$caseMatch.Groups[2].Value
        $cycles = [int]$caseMatch.Groups[1].Value
        $allResults += [pscustomobject]@{
            processor='custom_cpu'; configuration='scalar software-multiply'; N=[int]$case.Name.Substring(1); mac_count=$case.MacCount
            correctness='PASS'; expected_hex=('0x' + $case.Expected); total_cycles=$cycles; retired_instructions=$retired
            loads=[int]$counterMatch.Groups[1].Value; stores=[int]$counterMatch.Groups[2].Value
            branches_taken=[int]$counterMatch.Groups[3].Value; branches_not_taken=[int]$counterMatch.Groups[4].Value
            jumps=[int]$counterMatch.Groups[5].Value; control_flushes=[int]$counterMatch.Groups[6].Value
            fetch_waits=[int]$counterMatch.Groups[7].Value; memory_waits=[int]$counterMatch.Groups[8].Value
            data_hazard_stalls=[int]$counterMatch.Groups[9].Value; load_use_stalls=[int]$counterMatch.Groups[10].Value
            multiply_emulation_instructions=[int]$caseMatch.Groups[4].Value
            add=[int]$opcodeMatch.Groups[1].Value; sub=[int]$opcodeMatch.Groups[2].Value; addi=[int]$opcodeMatch.Groups[3].Value
            opcode_load=[int]$opcodeMatch.Groups[4].Value; opcode_store=[int]$opcodeMatch.Groups[5].Value
            opcode_beq=[int]$opcodeMatch.Groups[6].Value; opcode_jump=[int]$opcodeMatch.Groups[7].Value
            cycles_per_mac=($cycles / [double]$case.MacCount); instructions_per_mac=($retired / [double]$case.MacCount)
            log=$xsimLog
        }
    }
    $allResults | Export-Csv -NoTypeInformation -Path $ResultsCsv
    $allResults | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 -Path $ResultsJson
    Write-Host "Results written to $ResultsCsv and $ResultsJson"
} finally {
    Set-Location $oldLocation
}
