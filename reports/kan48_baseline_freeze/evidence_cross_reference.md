# KAN-48 evidence cross-reference

| Area | Result | Evidence |
|---|---|---|
| KAN-44 provenance | PASS | `reports/kan44_cpu_provenance/` |
| KAN-45 clean rebuild | PASS | `reports/kan45_clean_rebuild/`, 4,254/0 clean-clone result |
| KAN-46 regression | PASS | `reports/fyp_baseline_validation/`, focused H1.3b-T2 result 4,254/0 |
| KAN-47 smoke tests | PASS | `reports/kan47_smoke_tests/`, five tests × five runs |
| KAN-50 workload benchmark | PASS | `reports/kan50_processor_benchmark/`, exact output `[-116, 15, -97, 90]` |
| KAN-51 counter validation | PASS | `reports/kan51_instrumentation/`, repeated controlled tests stable |
| New acceleration introduced | NO | RTL comparison against `2731a782` is empty |
| CPU RTL changed | NO | Candidate processor-defining files are identical to inherited reference |
| ISA changed | NO | `cpu_defs_pkg.sv`, decoder and control files are identical |
| Baseline ready to freeze | YES | Final validation passed on the candidate revision |

