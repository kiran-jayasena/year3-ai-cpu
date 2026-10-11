$Root = Split-Path -Parent $MyInvocation.MyCommand.Path

function U32([Int64]$Value) {
    return [UInt32]([BitConverter]::ToUInt32([BitConverter]::GetBytes([Int32]$Value), 0))
}

function Enc([string]$Op, [int]$Rd=0, [int]$Rs1=0, [int]$Rs2=0, [int]$Imm=0) {
    $ops = @{ NOP=0; ADD=1; SUB=2; ADDI=6; LOAD=7; STORE=8; BEQ=9; JUMP=10 }
    if ($Imm -lt -4096 -or $Imm -gt 4095) { throw "Immediate out of range: $Imm" }
    $word = (($ops[$Op] -band 0xf) -shl 28) -bor (($Rd -band 0x1f) -shl 23) -bor (($Rs1 -band 0x1f) -shl 18) -bor (($Rs2 -band 0x1f) -shl 13) -bor ($Imm -band 0x1fff)
    return (U32 $word)
}

function Add-Inst([ref]$Program, [string]$Op, [int]$Rd=0, [int]$Rs1=0, [int]$Rs2=0, [object]$Imm=0) {
    $Program.Value += [PSCustomObject]@{ kind="inst"; op=$Op; rd=$Rd; rs1=$Rs1; rs2=$Rs2; imm=$Imm; multiply=$false }
}

function Add-Label([ref]$Program, [string]$Name) {
    $Program.Value += [PSCustomObject]@{ kind="label"; name=$Name }
}

function Resolve-Program([object[]]$Program, [string]$OutPath, [string]$MetaPath) {
    $labels = @{}; $pc = 0
    foreach ($item in $Program) { if ($item.kind -eq "label") { $labels[$item.name] = $pc } else { $pc++ } }
    $lines = @(); $multiplyPcs = @(); $pc = 0
    foreach ($item in $Program) {
        if ($item.kind -eq "label") { continue }
        if (($item.imm -is [string]) -and $labels.ContainsKey([string]$item.imm)) { $imm = $labels[$item.imm] - $pc }
        else { $imm = [int]$item.imm }
        $word = Enc $item.op $item.rd $item.rs1 $item.rs2 $imm
        $lines += ("{0:x8}" -f $word)
        if ($item.multiply) { $multiplyPcs += $pc }
        $pc++
    }
    if ($lines.Count -gt 256) { throw "$OutPath exceeds the frozen 256-word instruction memory" }
    while ($lines.Count -lt 256) { $lines += "00000000" }
    $lines -join "`n" | Set-Content $OutPath -Encoding ascii
    @{ instruction_words = $pc; multiply_pcs = $multiplyPcs } | ConvertTo-Json | Set-Content $MetaPath -Encoding utf8
}

function Add-Multiply([ref]$Program, [int]$Magnitude, [bool]$Negative) {
    Add-Inst $Program ADD 8 0 0
    for ($j = 0; $j -lt $Magnitude; $j++) {
        if ($Negative) { Add-Inst $Program SUB 8 8 6 }
        else { Add-Inst $Program ADD 8 8 6 }
        $Program.Value[$Program.Value.Count - 1].multiply = $true
    }
}

$A16 = @(3,-2,5,-4,7,-1,2,-6,4,-3,1,-5,6,-7,0,8)
$B16 = @(-3,4,-1,-2,2,-5,6,3,-4,7,-8,1,-2,5,9,-1)
$P16 = @()
Add-Inst ([ref]$P16) ADDI 1 0 0 0
Add-Inst ([ref]$P16) ADDI 2 0 0 64
Add-Inst ([ref]$P16) ADDI 4 0 0 0
for ($i = 0; $i -lt 16; $i++) {
    Add-Inst ([ref]$P16) LOAD 6 1 0 0
    Add-Inst ([ref]$P16) LOAD 7 2 0 0
    Add-Inst ([ref]$P16) ADDI 1 1 0 4
    Add-Inst ([ref]$P16) ADDI 2 2 0 4
    Add-Multiply ([ref]$P16) ([Math]::Abs($B16[$i])) ($B16[$i] -lt 0)
    Add-Inst ([ref]$P16) ADD 4 4 8
}
# STORE encodes the address base in rs1 and the value in rs2; rd is ignored.
Add-Inst ([ref]$P16) STORE 0 0 4 0
Add-Inst ([ref]$P16) NOP
Resolve-Program $P16 (Join-Path $Root "n16/custom_scalar.mem") (Join-Path $Root "n16/custom_scalar_metadata.json")

$P128 = @()
Add-Inst ([ref]$P128) ADDI 1 0 0 0
Add-Inst ([ref]$P128) ADDI 2 0 0 512
Add-Inst ([ref]$P128) ADDI 3 0 0 128
Add-Inst ([ref]$P128) ADDI 4 0 0 0
Add-Inst ([ref]$P128) ADDI 5 0 0 1
Add-Inst ([ref]$P128) ADDI 10 0 0 1
Add-Label ([ref]$P128) loop
Add-Inst ([ref]$P128) LOAD 6 1 0 0
Add-Inst ([ref]$P128) LOAD 7 2 0 0
Add-Inst ([ref]$P128) ADDI 1 1 0 4
Add-Inst ([ref]$P128) ADDI 2 2 0 4
Add-Inst ([ref]$P128) ADD 8 0 0 0
Add-Inst ([ref]$P128) ADD 9 7 0 0
Add-Label ([ref]$P128) mul_loop
Add-Inst ([ref]$P128) BEQ 0 9 0 "mul_done"
$P128[$P128.Count - 1].multiply = $true
Add-Inst ([ref]$P128) ADD 8 8 6
$P128[$P128.Count - 1].multiply = $true
Add-Inst ([ref]$P128) ADDI 9 9 0 -1
$P128[$P128.Count - 1].multiply = $true
Add-Inst ([ref]$P128) JUMP 0 0 0 "mul_loop"
$P128[$P128.Count - 1].multiply = $true
Add-Label ([ref]$P128) mul_done
Add-Inst ([ref]$P128) BEQ 0 5 10 "add_path"
Add-Inst ([ref]$P128) SUB 4 4 8
Add-Inst ([ref]$P128) JUMP 0 0 0 "sign_done"
Add-Label ([ref]$P128) add_path
Add-Inst ([ref]$P128) ADD 4 4 8
Add-Label ([ref]$P128) sign_done
Add-Inst ([ref]$P128) ADDI 3 3 0 -1
Add-Inst ([ref]$P128) BEQ 0 3 0 "finish"
Add-Inst ([ref]$P128) SUB 5 0 5
Add-Inst ([ref]$P128) JUMP 0 0 0 "loop"
Add-Label ([ref]$P128) finish
Add-Inst ([ref]$P128) STORE 0 0 4 0
Add-Inst ([ref]$P128) NOP
Resolve-Program $P128 (Join-Path $Root "n128/custom_scalar.mem") (Join-Path $Root "n128/custom_scalar_metadata.json")

# Custom N=128 data uses magnitude arrays to make signed software multiplication
# expressible on the frozen ISA. The sign of b alternates and is represented by
# the x5 +/-1 state in the generated loop. The canonical signed vectors remain
# the correctness reference for every processor.
$A128 = @(); $B128 = @(); $Data128 = @()
for ($i = 0; $i -lt 128; $i++) {
    $a = ((17 * $i + 3) % 8) + 1
    $b = ((29 * $i + 5) % 8) + 1
    $A128 += $a; $B128 += $b; $Data128 += $a
}
$Data128 += $B128
($Data128 | ForEach-Object { "{0:x8}" -f (U32 $_) }) -join "`n" | Set-Content (Join-Path $Root "n128/custom_data.mem") -Encoding ascii

$Data16 = @()
$Data16 += $A16; $Data16 += $B16
($Data16 | ForEach-Object { "{0:x8}" -f (U32 $_) }) -join "`n" | Set-Content (Join-Path $Root "n16/custom_data.mem") -Encoding ascii
