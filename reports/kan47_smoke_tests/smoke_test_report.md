# KAN-47 minimal independent smoke tests

Tested commit: `3ca5803d8de6a58eeb3cf9541a61501426e4ea43` on the current development branch.

These tests independently reconfirm architectural behaviour; they are separate from KAN-51 counter validation. KAN-46 remains the full inherited regression (4,254 checks, 0 failures).

| Test | Expected | Actual runs | Cycles | Retired | Stable | Result |
|---|---:|---|---|---|---|---|
| reset_startup | 1 | `[1, 1, 1, 1, 1]` | 7-7 | 2-2 | yes | PASS |
| scalar_arithmetic | 7 | `[7, 7, 7, 7, 7]` | 10-10 | 5-5 | yes | PASS |
| taken_branch | 7 | `[7, 7, 7, 7, 7]` | 13-13 | 5-5 | yes | PASS |
| load_store | 43 | `[43, 43, 43, 43, 43]` | 10-10 | 4-4 | yes | PASS |
| load_use_dependency | 10 | `[10, 10, 10, 10, 10]` | 10-10 | 4-4 | yes | PASS |

## Test definitions

- **reset_startup:** reset is asserted, fetch entry is checked at PC 0, then ADDI/STORE produces 1.
- **scalar_arithmetic:** computes `5 + 7 = 12`, then `12 - 5 = 7`.
- **taken_branch:** taken BEQ skips wrong-path value 99 and stores 7.
- **load_store:** stores 43, loads it back, and stores the loaded value at the sentinel address.
- **load_use_dependency:** loads 5 and immediately doubles it through a dependent ADD, producing 10.

All five tests passed on all five repetitions. Cycle and retired-instruction values are recorded only to show repeatability; no performance or bottleneck interpretation is made.

CPU RTL and ISA were unchanged. No inherited CPU defect was observed.
