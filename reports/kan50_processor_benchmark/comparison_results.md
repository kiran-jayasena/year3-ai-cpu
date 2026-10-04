# KAN-50 processor representative benchmark

The Conv2 representative kernel ran on the unchanged H1.3b/T2 candidate CPU using only baseline scalar ISA instructions. No MAC8 or DOT4ACC instruction is present in the generated program.

## Result

- Status: **PASS**
- Expected integer outputs: `[-116, 15, -97, 90]`
- Measured outputs for every run: `[-116, 15, -97, 90]`
- Exact integer match: **yes**
- Program image: 33 / 256 words (132 / 1024 bytes)
- Data image used: 114 / 256 words (456 / 1024 bytes)

| Run | Output values | Cycles | Retired instructions | Result |
| ---: | --- | ---: | ---: | --- |
| 1 | `[-116, 15, -97, 90]` | 1464 | 962 | PASS |
| 2 | `[-116, 15, -97, 90]` | 1464 | 962 | PASS |
| 3 | `[-116, 15, -97, 90]` | 1464 | 962 | PASS |
| 4 | `[-116, 15, -97, 90]` | 1464 | 962 | PASS |
| 5 | `[-116, 15, -97, 90]` | 1464 | 962 | PASS |

All five runs in each of two independent XSim invocations produced identical outputs, cycle counts, and retired-instruction counts.

The existing H1.3b/T2 architectural regression also passed: 4,254 checks and 0 failures. See `existing_core_regression.log`.

Cycle and instruction values are recorded only as repeatability evidence. No bottleneck interpretation is made.
