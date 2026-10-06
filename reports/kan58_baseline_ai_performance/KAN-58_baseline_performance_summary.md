# KAN-58 Baseline AI Workload Performance

## Baseline and workload

| Field | Value |
|---|---|
| Baseline tag | `fyp-stage3-baseline` |
| Baseline commit | `f6b25ca196493858cc2b501a0324c4a794c0dd94` |
| CPU/top | `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2` / `fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2` |
| FPGA/board | `xc7a35tcpg236-1` / Basys 3 |
| Workload | Conv2-derived quantised representative tile from the frozen MNIST CNN |
| Selection | Conv2, sample index 2, output channel 0, input channel 0, 2×2 output tile |
| Golden reference | `[-116, 15, -97, 90]` |
| Validated clock | 93.000 MHz (10.752688172 ns, from KAN-56) |
| Useful operations | 36 MAC-equivalent products (4 outputs × 9 products) |

## Measurements and derived metrics

| Metric | Value |
|---|---:|
| Total cycles | 1,464 |
| Retired instructions | 962 |
| CPI | 1.5218295 |
| Instructions/MAC | 26.7222222 |
| Cycles/MAC | 40.6666667 |
| MACs/cycle | 0.02459016 |
| Execution time | 15.741935 µs |
| Repeated runs | 5 |
| Deterministic counts | Yes |
| Correct output | Yes, exact integer match |

Calculations use the fixed 36-product convention for this tile:

- CPI = `1464 / 962`
- Instructions/MAC = `962 / 36`
- Cycles/MAC = `1464 / 36`
- MACs/cycle = `36 / 1464`
- Execution time = `1464 / 93,000,000` seconds

## Per-run results

| Run | Cycles | Retired instructions | Output | Correct? |
|---:|---:|---:|---|---|
| 1 | 1,464 | 962 | `[-116, 15, -97, 90]` | PASS |
| 2 | 1,464 | 962 | `[-116, 15, -97, 90]` | PASS |
| 3 | 1,464 | 962 | `[-116, 15, -97, 90]` | PASS |
| 4 | 1,464 | 962 | `[-116, 15, -97, 90]` | PASS |
| 5 | 1,464 | 962 | `[-116, 15, -97, 90]` | PASS |

The independent KAN-50 evidence records the same five runs in two simulator repetitions, all with identical outputs and counters. The KAN-51 instrumentation evidence validates the counter semantics used by these measurements.

## Execution path and fairness

The CPU baseline contains `dot4acc_pipeline_inst` and its four DSP48E1 resources. However, the KAN-50 benchmark program contains only `ADDI`, `ADD`, `SUB`, `LOAD`, `STORE`, `BEQ`, and `JUMP`; it contains no DOT4ACC or MAC8 instruction. Therefore this measured workload does **not** exercise the existing DOT4ACC datapath, although that datapath remains present in the frozen CPU design. The products are implemented by software repeated addition/subtraction, as documented by the KAN-50 representative-kernel definition.

## Scope and conclusion

The Conv2-derived representative workload executes correctly and deterministically on the exact frozen baseline. Its output matches the independent S2/S3 golden reference, and cycle/instruction counts are stable across five runs. These values are the KAN-58 baseline performance measurements for later apples-to-apples comparison.

No CPU architecture, RTL, ISA, memory system, constraints, workload algorithm, or accelerator functionality was changed. No compute, memory, control, or other bottleneck conclusion is made; this task records performance only.

