$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $repoRoot

$vivado = "C:\AMDDesignTools\2026.1\Vivado\bin"
$runDir = "experiments/dot4acc_nop_scheduling"
$baseline = "programs/kan50_conv2_tile_dot4acc_scheduled.mem"
$current = "$runDir/current_schedule.mem"
$source = "$runDir/tb_dot4acc_nop_schedule.sv"
$result = "$runDir/current_result.csv"
$resultsCsv = "$runDir/dot4acc_nop_scheduling_results.csv"
$expectedBaselineHash = "62C8787C2390006EF6216286FB7825E1D7B05B5C02485054BA740D000FAD7639"
$actualBaselineHash = (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash
if ($actualBaselineHash -ne $expectedBaselineHash) {
    throw "Baseline benchmark checksum changed: expected $expectedBaselineHash, got $actualBaselineHash"
}

function New-Schedule {
    param(
        [string] $Name,
        [int] $LoadGap,
        [int] $DotGap
    )

    $words = @(Get-Content $baseline | Where-Object { $_.Trim().Length -gt 0 })
    $nonNop = @($words | Where-Object { $_.Trim().Substring(0, 1) -ne "0" })
    $out = New-Object System.Collections.Generic.List[string]
    $nonNopIndex = 0

    foreach ($word in $nonNop) {
        $clean = $word.Trim().ToUpperInvariant()
        $out.Add($clean)
        $opcode = $clean.Substring(0, 1)
        $nextOpcode = ""
        if ($nonNopIndex + 1 -lt $nonNop.Count) {
            $nextOpcode = $nonNop[$nonNopIndex + 1].Trim().Substring(0, 1)
        }
        if ($opcode -eq "7") {
            $gap = if ($nextOpcode -eq "7") { $LoadGap } elseif ($nextOpcode -eq "C") { $DotGap } else { 0 }
            for ($i = 0; $i -lt $gap; $i++) { $out.Add("00000000") }
        }
        $nonNopIndex++
    }

    while ($out.Count -lt 256) { $out.Add("00000000") }
    if ($out.Count -gt 256) { throw "$Name generated more than 256 words" }
    $path = "$runDir/$Name.mem"
    Set-Content -LiteralPath $path -Value $out
    return [pscustomobject]@{ Name = $Name; LoadGap = $LoadGap; DotGap = $DotGap; Path = $path; Nops = (20 * $LoadGap) + (4 * $DotGap) }
}

$schedules = @(
    (New-Schedule "s6_d10_original" 6 10),
    (New-Schedule "s5_d9" 5 9),
    (New-Schedule "s4_d8" 4 8),
    (New-Schedule "s3_d7" 3 7),
    (New-Schedule "s2_d6" 2 6),
    (New-Schedule "s1_d5" 1 5),
    (New-Schedule "s0_d4" 0 4),
    (New-Schedule "s6_d0" 6 0),
    (New-Schedule "s0_d10" 0 10),
    (New-Schedule "s0_d0" 0 0)
)

& (Join-Path $vivado "xvlog.bat") -sv `
    rtl/cpu_defs_pkg.sv rtl/bram_instr_mem.sv rtl/bram_data_mem.sv `
    rtl/dot4acc_pipeline.sv `
    rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv $source
if ($LASTEXITCODE -ne 0) { throw "xvlog failed" }

& (Join-Path $vivado "xelab.bat") tb_dot4acc_nop_schedule -s tb_dot4acc_nop_schedule_sim
if ($LASTEXITCODE -ne 0) { throw "xelab failed" }

Set-Content -LiteralPath $resultsCsv -Value "schedule,load_gap,dot_gap,generated_nops,cycles,retired,measured_nops,dot4acc,loads,stores,fetch_waits,memory_waits,hazard_stalls,load_use_stalls,pipeline_fill,output_pass,completed,status"

foreach ($schedule in $schedules) {
    Copy-Item -LiteralPath $schedule.Path -Destination $current -Force
    if (Test-Path -LiteralPath $result) { Remove-Item -LiteralPath $result -Force }
    $log = "$runDir/$($schedule.Name).log"
    $output = & (Join-Path $vivado "xsim.bat") tb_dot4acc_nop_schedule_sim -runall 2>&1
    $output | Set-Content -LiteralPath $log
    $passedProcess = ($LASTEXITCODE -eq 0)
    if ($passedProcess -and (Test-Path -LiteralPath $result)) {
        $row = (Import-Csv -LiteralPath $result)[0]
        $status = if ($row.output_pass -eq "1" -and $row.completed -eq "1") { "PASS" } else { "FAIL" }
        $fields = @(
            $schedule.Name, $schedule.LoadGap, $schedule.DotGap, $schedule.Nops,
            $row.cycles, $row.retired, $row.nops, $row.dot4acc, $row.loads,
            $row.stores, $row.fetch_waits, $row.memory_waits,
            $row.hazard_stalls, $row.load_use_stalls, $row.pipeline_fill,
            $row.output_pass, $row.completed, $status
        )
        Add-Content -LiteralPath $resultsCsv -Value ($fields -join ',')
    } else {
        Add-Content -LiteralPath $resultsCsv -Value ("{0},{1},{2},{3},,,,,,,,,,,,,,,FAIL" -f $schedule.Name,$schedule.LoadGap,$schedule.DotGap,$schedule.Nops)
    }
}

Write-Host "NOP scheduling sweep completed: $resultsCsv"
