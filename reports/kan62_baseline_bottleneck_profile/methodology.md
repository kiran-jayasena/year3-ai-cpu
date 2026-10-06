# KAN-62 Profiling Methodology

## Baseline and workload

The exact KAN-58 program `programs/kan50_conv2_tile.mem` was run with the exact KAN-58 data and golden files on the frozen CPU RTL at tag `fyp-stage3-baseline` / commit `f6b25ca196493858cc2b501a0324c4a794c0dd94`. The profiling testbench is observational: it connects existing retirement, counter, and branch outputs and does not modify RTL, ISA, memories, constraints, or the benchmark.

## Trace collection

`tb_kan62_profile.sv` records every `retire_valid` event as `cycle, retired_index, pc, opcode, mem_write, mem_addr`. It also records the existing CPU counters at the sentinel store. The trace run reproduced 1,464 cycles, 962 retired instructions, and the exact golden output `[-116, 15, -97, 90]`.

Two independent profiling runs produced identical trace SHA-256 values: `1ab45a37bd227c8dfE26BDDD3E77F8780101A8FEAF6626C201ED18D148D5337D`. The retained files are `execution_trace_run1.txt` and `execution_trace_run2.txt`.

## Instruction classification

The opcode count is the primary mutually exclusive classification. ADD and SUB are arithmetic/accumulation. LOAD and STORE are memory operations. BEQ and JUMP are control. ADDI instances are classified by static program counter: PCs 0x2c/0x30/0x34/0x70 are address generation; PCs 0x48/0x60/0x74 are loop-counter updates; the initial setup ADDIs at PCs 0x00/0x04/0x08/0x0c/0x14/0x1c are immediate setup/constants. This makes the category totals sum exactly to 962.

Useful work is defined as the 36 quantised Conv2 products: four outputs, each with a 3×3 product set. All other retired instructions are overhead for this analysis.

## Cycle attribution

The ideal reference is one cycle per retired instruction (962). Excess cycles are `1464 - 962 = 502`. Existing counters directly report pipeline fill 6, control-hazard flush 216, data-hazard 0, load-use 0, instruction-fetch wait 0, and memory wait 0. The residual `502 - 6 - 216 = 280` is retained as unclassified; it is not silently assigned to memory or hazards. The measured counters are treated as a partition for this bookkeeping, but any overlap not exposed by the instrumentation would remain a limitation.

Wrong-path instructions flushed (281) and branch/jump counts are reported as control-flow evidence, not as cycle counts. No claim is made that each flushed instruction equals one cycle.

## DOT4ACC fairness

The frozen CPU includes `dot4acc_pipeline_inst`, but the KAN-58 program has zero MAC8/DOT4ACC retirements. The profiling does not disable or modify that hardware.
