# KAN-48 final pre-tag validation

Validation was run in a separate clone at candidate pre-freeze HEAD `8eef377277c808cc48e15fd8d2f86ef1f218277a`, so existing main-repository evidence was not overwritten.

| Validation | Result |
|---|---|
| H1.3b-T2 baseline regression | PASS: 4,254 checks, 0 failures |
| KAN-47 reset/start-up | PASS, 5/5 stable |
| KAN-47 scalar arithmetic | PASS, 5/5 stable |
| KAN-47 taken branch | PASS, 5/5 stable |
| KAN-47 load/store | PASS, 5/5 stable |
| KAN-47 load-use dependency | PASS, 5/5 stable |
| KAN-50 output | PASS: `[-116, 15, -97, 90]` |
| KAN-50 repeatability | PASS: 1,464 cycles and 962 retired instructions on every run |
| KAN-51 controlled instrumentation validation | PASS; two simulator repetitions identical |
| CPU RTL/ISA comparison | PASS: no differences from `2731a782` |

Cycle and retired-instruction values are recorded only as repeatability evidence. No bottleneck or S4 interpretation is made here.

