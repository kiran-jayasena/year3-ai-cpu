# Controlled DOT4ACC microbenchmark analysis

## Scope

The frozen `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2` RTL was
compiled unchanged with the existing DOT4ACC profiling-style XSim flow. No
ISA, RTL, historical benchmark, or existing report was modified.

The three experiment classes are:

- **A — register-resident DOT4ACC:** operands are loaded into registers during
  testbench setup, then the program issues a contiguous same-accumulator DOT
  chain followed by one store.
- **B — load-only stream:** each group performs two BRAM loads followed by a
  NOP, then one store. This matches the combined program's instruction count
  without performing DOT arithmetic.
- **C — LOAD + LOAD + DOT4ACC:** the current packed memory-fed kernel structure,
  with two operand loads and one DOT per group.

All cases use deterministic data and exact output checks. Raw data is in
`results.csv`.

## Results

| Family | DOTs/groups | Cycles | Retired | DOT4ACC | Loads | Stores | Fetch waits | Memory waits | Hazard stalls | Load-use stalls | Fill | CPI | Cycles/DOT |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A resident | 4 | 15 | 5 | 4 | 0 | 1 | 5 | 0 | 0 | 0 | 8 | 3.0000 | 3.7500 |
| A resident | 16 | 27 | 17 | 16 | 0 | 1 | 5 | 0 | 0 | 0 | 8 | 1.5882 | 1.6875 |
| A resident | 32 | 43 | 33 | 32 | 0 | 1 | 5 | 0 | 0 | 0 | 8 | 1.3030 | 1.3438 |
| A resident | 64 | 75 | 65 | 64 | 0 | 1 | 5 | 0 | 0 | 0 | 8 | 1.1538 | 1.1719 |
| B load-only | 4 | 18 | 13 | 0 | 8 | 1 | 0 | 0 | 0 | 0 | 6 | 1.3846 | N/A |
| B load-only | 16 | 54 | 49 | 0 | 32 | 1 | 0 | 0 | 0 | 0 | 6 | 1.1020 | N/A |
| B load-only | 32 | 102 | 97 | 0 | 64 | 1 | 0 | 0 | 0 | 0 | 6 | 1.0515 | N/A |
| B load-only | 64 | 198 | 193 | 0 | 128 | 1 | 0 | 0 | 0 | 0 | 6 | 1.0259 | N/A |
| C combined | 4 | 39 | 13 | 4 | 8 | 1 | 15 | 1 | 1 | 1 | 6 | 3.0000 | 9.7500 |
| C combined | 16 | 135 | 49 | 16 | 32 | 1 | 51 | 1 | 1 | 1 | 6 | 2.7551 | 8.4375 |
| C combined | 32 | 263 | 97 | 32 | 64 | 1 | 99 | 1 | 1 | 1 | 6 | 8.2188 |
| C combined | 64 | 519 | 193 | 64 | 128 | 1 | 195 | 1 | 1 | 1 | 6 | 8.1094 |

The C combined N=32-DOT case is the previously reported N=128 workload:
263 cycles, 97 retired instructions and 99 fetch-wait events.

## Fixed and scaling components

The measured cycle relationships are exact over the tested sizes:

| Family | Measured relationship | Fixed component | Scaling slope |
|---|---|---:|---:|
| A resident | `cycles = 11 + 1*K` | 11 cycles | 1 cycle/DOT |
| B load-only | `cycles = 6 + 3*K` | 6 cycles | 3 cycles/group |
| C combined | `cycles = 7 + 8*K` | 7 cycles | 8 cycles/group |

Here `K` is the number of DOT groups, and B's group is two loads plus one
NOP. Retired instructions are `K+1` for A and `3K+1` for B/C.

The combined workload is not the sum of A and B. Its interaction term is:

`C - A - B = 4K - 10` cycles.

For K=32, this is 118 cycles. This is the cost of combining operand loads
with DOT issue and dependency/ frontend scheduling; it is not explained by
the standalone resident-DOT or load-only slopes.

Counter slopes reinforce this result:

- A fetch waits are fixed at 5; resident DOT execution scales at one cycle per
  DOT, consistent with an already effective II=1 DOT path after startup.
- B has zero fetch-wait, memory-wait and hazard counters that grow with K; its
  three-cycle slope is the ordinary load/NOP instruction stream.
- C fetch waits grow as `3K+3`: 15, 51, 99 and 195. Memory, hazard and
  load-use counters remain fixed at 1 each.

## N=128 / K=32 reconciliation

For the combined N=128 run:

- Total cycles: 263
- Retired instructions: 97
- `263 - 97 = 166` cycles beyond the retirement count
- Fetch-wait events: 99
- Memory waits: 1
- Data-hazard stalls: 1
- Load-use stalls: 1
- Pipeline fill: 6
- Control flushes: 0

The counters sum to 108 if treated naively, not 166. This is expected: the
frozen counters count events on different pipeline conditions and are not a
mutually exclusive per-cycle attribution. Some events overlap with cycles in
which an instruction also retires, while startup, drain, BRAM timing and
frontend state transitions are not represented by one additive reason.

The important correlation is across workload sizes, not arithmetic addition:
fetch waits rise by three per DOT group, while memory/hazard/load-use/fill
remain fixed. The remaining four cycles per group in the combined slope are
the measured interaction between operand arrival and DOT scheduling, not
evidence of a growing data-memory wait.

## Bottleneck ranking

1. **Fused load/DOT or operand-delivery mechanism — strongest candidate.**
   The combined slope is 8 cycles/DOT, versus 1 cycle/DOT for resident DOT and
   3 cycles/group for the load-only stream. The extra interaction is therefore
   the largest measured cost.
2. **Instruction-fetch improvement — plausible second candidate.** Fetch waits
   grow by 3 per combined group and are absent in the load-only stream, but
   resident DOT still has five fixed fetch waits and the counter is not an
   additive cycle partition. Fetch improvement should target the combined
   load/issue pattern, not be justified as a standalone 99-cycle sum.
3. **DOT4ACC scheduling/pipelining improvement — limited evidence.** The
   register-resident path already achieves a one-cycle-per-DOT slope. Further
   DOT arithmetic pipelining is therefore not the primary measured bottleneck,
   although completion/hold behavior should remain observable in any future
   experiment.
4. **More MAC lanes — currently weakly supported.** Arithmetic is already
   compressed into one four-lane DOT instruction and resident DOT scales at
   one cycle per instruction. Additional lanes would not remove the measured
   load/fetch/issue interaction by themselves.
5. **Scratchpad/banking — lowest priority from this evidence.** The memory-wait
   counter is fixed at 1 and does not scale in either load-only or combined
   tests. Loads consume instruction and scheduling bandwidth, but no growing
   memory starvation was measured.

## Conclusion

The remaining DOT4ACC bottleneck is primarily an **interaction between operand
loading and frontend/DOT issue scheduling**, with instruction-fetch waiting as
the clearest correlated counter. It is not primarily the DOT arithmetic
execution path: register-resident DOT4ACC achieves a one-cycle-per-DOT slope.

The evidence supports investigating a fused load/DOT or operand-delivery
mechanism first, followed by targeted instruction-fetch improvement. No
Variant A was selected or implemented.

## Reproduction

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File reports/dot4acc_microbench/run_microbench.ps1
```

The script compiles the frozen core and experiment-local testbench with Vivado
2026.1 XSim and writes `results.csv`, `xvlog.log`, `xelab.log` and `xsim.log`.
