# KAN-48 frozen Stage 3 experimental baseline

## Objective

Define the exact immutable Year III experimental baseline for S4 profiling, S5 acceleration selection, S7 implementation, and later baseline-versus-accelerated comparisons.

## Historical and Year III identities

The inherited provenance baseline is `fyp-baseline` / `2731a7820988863829c7074acd474ea06902e8f2`, containing the unchanged H1.3b-T2 CPU architecture. The Year III candidate before this evidence commit was `8eef377277c808cc48e15fd8d2f86ef1f218277a`, which contains the committed KAN-44 through KAN-51 verification, benchmark and measurement infrastructure.

The final tag will point to the dedicated KAN-48 evidence commit. Its full SHA is recorded in `baseline_identity.txt` and `tag_verification.txt` after the evidence commit is created.

## Why this candidate was selected

The candidate preserves the inherited unaccelerated CPU RTL and ISA while including:

- inherited provenance and clean-clone evidence;
- the full baseline regression record;
- independent architectural smoke tests;
- the deterministic AI-derived processor benchmark;
- validated cycle and retired-instruction instrumentation.

No CPU functional RTL, ISA, memory architecture, timing constraint, or accelerator mechanism was added by the Year III work included here.

## Final validation

The exact candidate revision passed the final pre-tag validation documented in `final_validation_summary.md`. The H1.3b-T2 regression passed 4,254/0; all KAN-47 smoke tests passed five repetitions; KAN-50 reproduced `[-116, 15, -97, 90]` with stable 1,464-cycle/962-retirement measurements; and KAN-51 controlled validation remained PASS.

## Tag and remote

The intended annotated tag is `fyp-stage3-baseline` with message `Stage 3 validated experimental baseline before AI acceleration`. It will be created only after the evidence commit is complete and the working tree is clean, then pushed explicitly (not with `git push --tags`). Local and remote verification will be recorded in `tag_verification.txt`.

## Conclusion

The Stage 3 experimental baseline contains new verification, benchmark and measurement infrastructure while preserving the inherited unaccelerated CPU architecture. Clean-build reproducibility, the inherited regression, independent smoke tests, workload execution and measurement instrumentation have been validated. The resulting annotated tag will serve as the immutable baseline for S4 profiling and subsequent baseline-versus-accelerated comparisons.
