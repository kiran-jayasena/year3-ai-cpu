[CmdletBinding()]
param(
    [string] $OutputPath
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')

if (-not $OutputPath) {
    $OutputPath = Join-Path $RepoRoot 'reports\fyp\environment.txt'
} elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $RepoRoot $OutputPath
}

function Invoke-CapturedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Command,
        [string[]] $Arguments = @()
    )

    try {
        $text = & $Command @Arguments 2>&1 | Out-String
        return $text.Trim()
    } catch {
        return "Unavailable: $($_.Exception.Message)"
    }
}

function Resolve-VivadoExecutable {
    $command = Get-Command vivado -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat',
        'C:\Xilinx\Vivado\2026.1\bin\vivado.bat'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

$windowsVersion = try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    "$($os.Caption) $($os.Version) build $($os.BuildNumber)"
} catch {
    [System.Environment]::OSVersion.VersionString
}

$gitVersion = Invoke-CapturedCommand -Command 'git' -Arguments @('--version')
$pythonVersion = Invoke-CapturedCommand -Command 'python' -Arguments @('--version')
$branch = Invoke-CapturedCommand -Command 'git' -Arguments @('-C', $RepoRoot.Path, 'branch', '--show-current')
$commit = Invoke-CapturedCommand -Command 'git' -Arguments @('-C', $RepoRoot.Path, 'rev-parse', 'HEAD')
$status = Invoke-CapturedCommand -Command 'git' -Arguments @('-C', $RepoRoot.Path, 'status', '--short', '--branch')
$vivado = Resolve-VivadoExecutable
$vivadoVersion = if ($vivado) {
    Invoke-CapturedCommand -Command $vivado -Arguments @('-version')
} else {
    'Unavailable: Vivado executable not found on PATH or at known 2026.1 locations'
}

$lines = @(
    "timestamp: $([DateTimeOffset]::Now.ToString('o'))",
    "hostname: $([System.Environment]::MachineName)",
    "windows_version: $windowsVersion",
    "git_version: $gitVersion",
    "python_version: $pythonVersion",
    "git_branch: $branch",
    "git_commit: $commit",
    'git_status:',
    $status,
    'vivado_version:',
    $vivadoVersion,
    'fpga_part: xc7a35tcpg236-1'
)

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$lines | Set-Content -LiteralPath $OutputPath -Encoding utf8
$lines | Write-Output
Write-Output "Environment record written to: $OutputPath"
