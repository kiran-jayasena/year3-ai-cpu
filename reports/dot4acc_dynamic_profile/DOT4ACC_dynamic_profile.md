# DOT4ACC dynamic instruction and cycle profile

## Scope and provenance

This is an experiment-local profile of the frozen
`cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2` RTL. No RTL, ISA,
historical benchmark evidence, or existing DOT4ACC benchmark was modified.
The exact Conv2 result is taken from the existing reproducible profile under
`reports/dot4acc_conv2_profile/`. The scaling run uses the same memory-fed
packed-DOT structure: two packed operand loads followed by a contiguous
DOT4ACC accumulation chain and one final store. Inputs are deterministic and
all outputs are checked against the signed lane reference model.

## Existing Conv2 dynamic instruction breakdown

The current Conv2 DOT4ACC program retires 207 instructions:

| Dynamic class | Count |
|---|---:|
| DOT4ACC | 12 |
| Loads | 24 |
| Stores | 5 |
| ADDI/address/setup | 6 |
| Branches | 0 |
| Jumps | 0 |
| Other instructions | 0 |
| NOPs | 160 |
| **Total** | **207** |

The requested classes sum to 47 non-NOP instructions. NOPs are reported
separately because they are dynamically retired instructions in this existing
scheduled image; omitting them would not reconcile with the 207 retirement
counter. Thus:

`12 + 24 + 5 + 6 + 160 = 207`.

The five stores include the four output stores and the benchmark completion
sentinel store. The specialised Conv2 program is branch-free and jump-free.

## Existing Conv2 cycle reconciliation

| Quantity | Measured value |
|---|---:|
| Total cycles | 232 |
| Retired instructions | 207 |
| Difference, total minus retired | 25 |
| Fetch-wait counter | 20 |
| Memory-wait counter | 0 |
| Data-hazard stalls | 0 |
| Load-use stalls | 0 |
| Control-flush cycles | 0 |
| Pipeline-fill counter | 6 |

The 25-cycle difference is the useful residual after comparing total elapsed
cycles with retirement count. The counters are not an additive partition of
time: pipeline fill, instruction-fetch waiting, retirement timing, and final
drain can overlap or be counted on different event boundaries. Therefore it
would be incorrect to calculate `6 + 20` as the exact 25-cycle decomposition.
The defensible reconciliation is that 25 cycles are outside the one-retirement
per-cycle count, with 20 explicitly attributed to fetch wait and the remaining
startup/drain/event-accounting difference not separately exposed by the frozen
counter interface. No data-memory wait or pipeline hazard explains the
residual.

## Scaling results

| Workload | N / MAC-equivalent | Cycles | Retired | DOT4ACC | Loads | Stores | ADDI/setup | Branches | Jumps | Other | Fetch waits | Memory waits | Hazard stalls | Load-use stalls | Cycles/MAC | Instructions/MAC | Correctness |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Small | 16 | 39 | 13 | 4 | 8 | 1 | 0 | 0 | 0 | 0 | 15 | 1 | 1 | 1 | 2.4375 | 0.8125 | PASS |
| Medium | 64 | 135 | 49 | 16 | 32 | 1 | 0 | 0 | 0 | 0 | 51 | 1 | 1 | 1 | 2.1094 | 0.7656 | PASS |
| Large | 128 | 263 | 97 | 32 | 64 | 1 | 0 | 0 | 0 | 0 | 99 | 1 | 1 | 1 | 2.0547 | 0.7578 | PASS |

The dynamic class identity is exact for every scaling case:

`retired = DOT4ACC + loads + stores = (N/4) + 2(N/4) + 1`.

The generated outputs were `0x00000A05`, `0x000027A5` and `0x00004F25` for
N=16, 64 and 128 respectively. Raw values are in `results.csv` and the
reproducible source/run files are in this directory.

## What grows with workload size?

The measured slopes are stable:

- Every additional DOT4ACC handles four MAC-equivalent operations.
- Every DOT adds two operand loads and three retired instructions in total.
- Cycles increase by approximately 8 cycles per DOT: 39 -> 135 -> 263.
- Fetch waits increase from 15 -> 51 -> 99, or approximately 3 fetch-wait
  cycles per additional DOT.
- Memory waits, hazard stalls, load-use stalls and pipeline fill remain fixed
  at 1, 1, 1 and 6 respectively in this run.
- Branches, jumps, ADDI/setup instructions and other instructions remain zero.

The explicit counter that grows most clearly is instruction-fetch waiting.
The remaining growing cycle cost is the repeated operand-delivery/issue
schedule: the CPU must retire two loads and then issue each DOT chain rather
than receiving a packed operand pair through a dedicated streaming path. The
data-memory wait counter does not grow, so the evidence does not support a new
cache, DMA engine, or banked scratchpad as the next enhancement.

## Bottleneck ranking

1. **Instruction delivery and operand-delivery schedule — strongest measured
   candidate.** Fetch waits scale with the number of DOT groups, and the
   memory-fed kernel repeats the load/load/DOT sequence for every group.
2. **DOT issue/control and pipeline scheduling — significant residual.** The
   total-cycle slope is about 8 cycles per DOT, while only about 3 of those
   cycles are classified as fetch wait. The frozen counters do not expose a
   disjoint name for the remaining repeated issue/hold/retirement cost.
3. **Data-memory latency — not supported as the dominant bottleneck.** The
   memory-wait counter is constant at 1 across all sizes; loads consume
   instructions and scheduling slots, but no growing memory wait is observed.
4. **Hazards — not supported as a scaling bottleneck.** Hazard and load-use
   counters remain constant at 1, and no branch or jump activity exists.
5. **Arithmetic throughput — already substantially compressed.** DOT4ACC
   count scales linearly but each instruction represents four lane MACs; the
   measured issue path, not scalar arithmetic, is now the limiting concern.

## Answer to the Year III question

After DOT4ACC removes the dominant scalar compute and control overhead, the
remaining cost that grows sufficiently with workload size to justify a new
investigation is the **instruction/operand delivery and DOT issue schedule**,
with fetch waiting as its clearest measured component. This supports profiling
or designing a bounded control/streaming improvement around existing DOT4ACC
operand delivery. It does **not** yet justify selecting or implementing
Variant A, and it does not justify a new memory subsystem based on these
measurements alone.

The next decision should remain measurement-led: distinguish fetch response,
load spacing, DOT hold, issue, completion and retirement on the same workload
before changing architecture.

## Reproduction

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File reports/dot4acc_dynamic_profile/run_profile.ps1
```

The script compiles the existing frozen RTL and the experiment-local
self-checking testbench with Vivado XSim. It writes `results.csv`,
`xvlog.log`, `xelab.log` and `xsim.log` in this directory.
