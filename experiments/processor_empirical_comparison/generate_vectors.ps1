$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Signed32([Int64]$Value) {
    $u = [UInt64]([BitConverter]::ToUInt32([BitConverter]::GetBytes([Int32]$Value), 0))
    if ($u -ge 2147483648) { return ([Int64]$u - 4294967296) }
    return [Int64]$u
}

function U32([Int64]$Value) {
    return [UInt32]([BitConverter]::ToUInt32([BitConverter]::GetBytes([Int32]$Value), 0))
}

function Emit-Case([string]$Name, [int[]]$A, [int[]]$B) {
    $CaseDir = Join-Path $Root $Name
    New-Item -ItemType Directory -Force -Path $CaseDir | Out-Null
    [Int64]$Sum = 0
    for ($i = 0; $i -lt $A.Count; $i++) { $Sum += $A[$i] * $B[$i] }
    $Result = Signed32 $Sum
    "index,a,b`n$((0..($A.Count-1) | ForEach-Object { "$_,$($A[$_]),$($B[$_])" }) -join "`n")`n" | Set-Content (Join-Path $CaseDir "vectors.csv") -Encoding utf8
    ($A | ForEach-Object { "{0:x8}" -f (U32 $_) }) -join "`n" | Set-Content (Join-Path $CaseDir "a_words.mem") -Encoding ascii
    ($B | ForEach-Object { "{0:x8}" -f (U32 $_) }) -join "`n" | Set-Content (Join-Path $CaseDir "b_words.mem") -Encoding ascii
    ("{0:x8}" -f (U32 $Result)) | Set-Content (Join-Path $CaseDir "golden.mem") -Encoding ascii
    @{
        vector_length = $A.Count
        mac_count = $A.Count
        operand_type = "signed int8"
        accumulator_type = "signed int32 modulo 2^32"
        expected_signed = $Result
        expected_hex = ("0x{0:X8}" -f (U32 $Result))
        layout = "canonical signed values; one word per operand in reference memory images"
    } | ConvertTo-Json | Set-Content (Join-Path $CaseDir "metadata.json") -Encoding utf8
    return @{ Hex = ("0x{0:X8}" -f (U32 $Result)); Signed = $Result }
}

$A16 = @(3,-2,5,-4,7,-1,2,-6,4,-3,1,-5,6,-7,0,8)
$B16 = @(-3,4,-1,-2,2,-5,6,3,-4,7,-8,1,-2,5,9,-1)
$A128 = @(); $B128 = @()
for ($i = 0; $i -lt 128; $i++) {
    $A128 += ((17 * $i + 3) % 8) + 1
    $b = ((29 * $i + 5) % 8) + 1
    if (($i % 2) -eq 1) { $b = -$b }
    $B128 += $b
}
$R16 = Emit-Case "n16" $A16 $B16
$R128 = Emit-Case "n128" $A128 $B128
@{
    n16_expected_hex = $R16.Hex
    n128_expected_hex = $R128.Hex
    cases = @("n16", "n128")
    generator = "PowerShell $($PSVersionTable.PSVersion)"
} | ConvertTo-Json | Set-Content (Join-Path $Root "vectors_manifest.json") -Encoding utf8
