# KAN-52 M3 Baseline Review

## Objective

This review is the Stage 3 decision gate for determining whether the project has established a reproducible, independently validated, unaccelerated CPU baseline ready for S4 workload profiling. It reviews retained evidence; it does not add profiling, optimisation, acceleration, or new CPU implementation.

## Baseline identity

| Item | Identity |
|---|---|
| Historical inherited baseline | Tag `fyp-baseline`, commit `2731a7820988863829c7074acd474ea06902e8f2` |
| Frozen Year III experimental baseline | Tag `fyp-stage3-baseline`, commit `f6b25ca196493858cc2b501a0324c4a794c0dd94` |
| Annotated tag object | `74d9c8615d9ae1d0af8cf4ca5d61fc1a58c07647` |
| CPU | `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2` |
| FPGA | `xc7a35tcpg236-1` |
| Toolchain | AMD Vivado 2026.1, XSim 2026.1 |
| Tag remote | `summer-source`; no `origin` remote is configured |

The current branch HEAD is `77ea91221b578ad6c2e4cd4c74c9732f4942dd7d`, newer than the immutable tag target. The post-tag commits are documentation-only; the Stage 3 baseline remains the tag target above.

## Acceptance review

| Criterion | Evidence | Result |
|---|---|---|
| Inherited CPU provenance recorded | `reports/kan44_cpu_provenance/` | PASS |
| Clean-clone/build reproducibility demonstrated | `reports/kan45_clean_rebuild/` | PASS |
| Baseline regression passes | KAN-46 evidence and KAN-48 final validation | PASS — 4,254 checks, 0 failures |
| AI-derived workload executes deterministically | `reports/kan50_processor_benchmark/` | PASS |
| Processor output matches independent S2 reference | KAN-50 processor results | PASS — exact `[-116, 15, -97, 90]` |
| Cycle and retired-instruction instrumentation validated | `reports/kan51_instrumentation/` | PASS |
| Candidate experimental baseline frozen | `reports/kan48_baseline_freeze/` and tag | PASS — `fyp-stage3-baseline` |
| Evidence retained and cross-referenced | KAN-44 through KAN-51 report directories | PASS |
| No new AI acceleration before S4 | KAN-48 RTL comparison | PASS — no CPU RTL/ISA change |
| Ready to proceed to S4 | This decision gate | PASS |

## Key validation results

- The inherited regression reproduced with 4,254 checks and 0 failures.
- KAN-47 independently passed reset/start-up, scalar arithmetic, taken branch, load/store, and load-use dependency tests. Each was repeated five times with stable results.
- The deterministic AI-derived Conv2 representative benchmark matched its independent software golden output exactly: `[-116, 15, -97, 90]`.
- The selected benchmark measurements were stable at 1,464 cycles and 962 retired instructions.
- KAN-51 validated counter semantics and repeatability using controlled programs and the selected workload.
- KAN-48 compared the candidate CPU and directly relevant wrapper/ISA RTL against the inherited baseline and found no functional differences.
- No accelerator, custom AI instruction, or other architectural optimisation was introduced.

## Reproducibility findings and limitations

- At KAN-45, the historical `fyp-baseline` tag was local-only and had to be fetched explicitly into the clean clone; this dependency is retained in the clean-rebuild report.
- `scripts/fyp/capture_environment.ps1` was absent at the historical revision, so the clean-clone environment was captured manually.
- The new `fyp-stage3-baseline` tag was pushed to `summer-source`; this repository has no `origin` remote.
- The current branch is three commits ahead of the frozen tag because of later documentation-only evidence updates. This does not alter the immutable tag target.

These are documented reproducibility limitations, not unsupported assumptions about the CPU results.

## Scientific boundary

The baseline measurements are reproducible and trustworthy. KAN-52 does not identify the CPU bottleneck and makes no bottleneck claim. Bottleneck identification and profiling are deferred to S4.

## Decision

**M3 decision: PASS.** Stage 3 has established a reproducible and independently validated unaccelerated experimental baseline. The inherited CPU provenance has been documented, the design reproduces from a clean checkout, the regression and independent smoke tests pass, the selected AI-derived workload executes deterministically against its golden reference, cycle and retired-instruction instrumentation is validated, and the experimental baseline has been frozen at `f6b25ca196493858cc2b501a0324c4a794c0dd94` under tag `fyp-stage3-baseline`. The project is ready to proceed to S4 workload profiling and bottleneck identification.

## S4 readiness

S4 now has an immutable unaccelerated comparison point, a reproducible processor benchmark, independently generated golden output, and validated cycle/retired-instruction counters. No S4 profiling was performed as part of this review.

## Evidence cross-reference

| Work item | Repository evidence |
|---|---|
| KAN-44 provenance | `reports/kan44_cpu_provenance/cpu_baseline_provenance.md`, `cpu_baseline_provenance.json` |
| KAN-45 clean rebuild | `reports/kan45_clean_rebuild/clean_rebuild_report.md`, `clean_rebuild_result.json` |
| KAN-46 regression | `reports/fyp_baseline_validation/` and final validation transcript under `reports/kan48_baseline_freeze/` |
| KAN-47 smoke tests | `reports/kan47_smoke_tests/smoke_test_report.md`, `smoke_test_results.json`, `repeated_runs.csv` |
| KAN-48 freeze | `reports/kan48_baseline_freeze/` and Git tag `fyp-stage3-baseline` |
| KAN-50 benchmark | `reports/kan50_processor_benchmark/processor_results.json` and comparison report |
| KAN-51 instrumentation | `reports/kan51_instrumentation/instrumentation_validation.md`, `instrumentation_validation.json` |

