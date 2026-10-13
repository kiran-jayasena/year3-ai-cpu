# KAN-64 Pipeline Hazard and Forwarding Verification

## Objective

KAN-64 requires reproducible evidence that applicable read-after-write (RAW)
dependencies, forwarding and stalls are covered. The audit was performed on
the active development branch at commit `7041824` (`fyp-development`). No Jira
issue was changed, and no commit was created.

## Implemented pipeline and applicable mechanisms

The frozen active core is
`rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`. It is a
single-issue, in-order design with a scalar fetch/IF-ID/ID-EX/EX-MEM/MEM-WB
retirement path. Instruction and data memories are synchronous BRAM-style
interfaces. DOT4ACC has a separate three-stage advancing arithmetic path with
issue, two metadata stages and completion/writeback; it is not an ordinary
five-stage scalar instruction.

Applicable dependency mechanisms are:

- decode-time writeback bypass for scalar operands and the MAC8/DOT4ACC
  accumulator source;
- EX/MEM and MEM/WB forwarding for scalar ALU results, MAC8 operands and
  branch operands;
- one decode bubble for LOAD-to-`rs1`, LOAD-to-`rs2` and LOAD-to-accumulator
  dependencies;
- DOT4ACC pre-completion source and accumulator dependency holds, with
  same-destination contiguous chain handling and completion forwarding;
- younger non-DOT holding while the DOT path is occupied when required;
- taken BEQ/JUMP redirects that invalidate younger frontend/ID-EX work, plus
  DOT cancellation and reset flushing;
- global `enable` freezing all in-flight state and counters.

Conventional hazards that are not applicable as separate mechanisms include
out-of-order/WAW scheduling and a general scoreboard for scalar instructions:
the scalar core is in-order and single-issue. A zero stall count in an
unrelated benchmark is not treated as hazard evidence.

## Verification coverage matrix

| Applicable behaviour | Evidence | Result |
|---|---|---|
| Back-to-back scalar arithmetic RAW | `tb/tb_cpu_core_pipeline_full.sv`, dependency arithmetic benchmark; checks x1/x2/x3/x4/x8/x9 results | PASS: current XSim run, 2,796 checks, 0 failures |
| Scalar EX/MEM and MEM/WB forwarding | `tb/tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`, `test_scalar_and_load_forwarding`; explicit forwarded rs1/rs2/accumulator checks | PASS: current XSim run, 4,254 checks, 0 failures |
| Scalar result used as STORE data | `tb/tb_cpu_core_pipeline_full.sv` memory/dependency tests; active-core DOT-to-STORE check | PASS: expected memory values and no duplicate side effects |
| LOAD-use to scalar rs1/rs2 | `tb/tb_cpu_core_pipeline_full.sv` load-use dependency; `tb/tb_kan47_smoke_tests.sv` load-use case | PASS: result checks and non-zero stall counter; KAN-47 75/75 checks |
| LOAD-use to accumulator/DOT source roles | Active-core testbench `test_scalar_and_load_forwarding` | PASS: all three roles checked; exactly one decode bubble per dependency |
| DOT source RAW against in-flight completion | Active-core `test_dot_destination_dependencies`; source dependency stall and completion-forwarding checks | PASS |
| DOT accumulator dependency and chain break | Active-core contiguous-chain and noncontiguous-accumulator tests | PASS: legal chain bypass and required hold both checked |
| DOT result consumed by ADD/SUB/STORE/BEQ | Active-core `test_dot_result_visibility_to_resumed_scalar_consumers` | PASS: architectural results, STORE and taken branch checked |
| Younger scalar hold behind DOT | Active-core `test_younger_hold_and_enable_freeze` | PASS: ADD, LOAD, STORE and control flow resume exactly once |
| Taken-branch/JUMP flush and wrong-path cancellation | Active-core `test_redirects` and `test_g1_chain_redirect_boundaries`; legacy full pipeline branch/jump tests | PASS: cancellation/redirect assertions and no wrong-path retirement |
| Reset flush and recovery | Active-core `test_reset_flush`; reset checks in KAN-47/KAN-51 | PASS |
| Global enable/stall freeze | Active-core freeze tests and `test_completion_freeze` | PASS: valid bits, destinations, side effects and completion remain stable |
| WAW/out-of-order hazard | Not applicable: scalar pipeline is in-order, single-issue; DOT ordering is explicitly tested | PASS as an architectural non-applicability determination |

The active-core testbench also exercises write-port arbitration, exactly-once
retirement, invalid/reserved DOT encodings, x0 protection and a deterministic
520-cycle issue-control stress sequence.

## Tests executed

All commands were run from the repository root with Vivado/XSim 2026.1.

1. Active-core architectural regression:

   ```powershell
   xvlog -sv rtl/cpu_defs_pkg.sv tb/dot4acc_reference_pkg.sv rtl/bram_instr_mem.sv rtl/bram_data_mem.sv rtl/dot4acc_pipeline.sv rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv tb/tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv
   xelab tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2 -s kan64_active_core_sim
   xsim kan64_active_core_sim -runall
   ```

   Result: `Stage D checks: 4254, failures: 0`; `TEST PASSED`.
   Observed totals: 145 accepted DOT transactions, 140 completed, 138
   retired, 7 reset-flushed and 27 cancelled before issue.

2. Legacy full scalar pipeline regression:

   ```powershell
   xvlog -sv rtl/cpu_defs_pkg.sv rtl/bram_instr_mem.sv rtl/bram_data_mem.sv rtl/cpu_core_pipeline_full.sv tb/tb_cpu_core_pipeline_full.sv
   xelab tb_cpu_core_pipeline_full -s kan64_pipeline_full_sim
   xsim kan64_pipeline_full_sim -runall
   ```

   Result: `Tests run: 2796`, `Tests failed: 0`; `PIPELINE FULL CUSTOM ISA
   TEST PASSED`. The mixed workload reported 20 load-use stalls and 20
   control flushes while checking architectural results and wrong-path safety.

3. KAN-47 independent smoke tests:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/run_kan47_smoke_tests.ps1
   ```

   XSim result: 75 checks, 0 failures; five repetitions each passed for reset,
   arithmetic, taken branch, load/store and load-use dependency. The wrapper
   exited non-zero only because `python` was unavailable for the optional
   summary step.

4. KAN-51 instrumentation validation:

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/run_kan51_instrumentation.ps1
   ```

   XSim result: 80 checks, 0 failures on both repetitions. The wrapper exited
   non-zero only because `python` was unavailable for the summary step. The
   committed/raw CSV evidence also remains in
   `reports/kan51_instrumentation/`.

5. The full historic runner was started with
   `powershell -ExecutionPolicy Bypass -File scripts/run_xsim_regression.ps1`.
   It began successfully under Vivado 2026.1 but was stopped by the execution
   time limit before the entire long regression completed. It is therefore not
   reported as a full-regression pass.

## Existing evidence reused

The main reusable evidence is the current active-core testbench and its direct
XSim result above. Supporting historical documentation is in
`docs/verification.md`, `docs/fyp/platform_comparison.md`,
`reports/kan47_smoke_tests/smoke_test_report.md` and
`reports/kan51_instrumentation/instrumentation_validation.md`. The source
comments and assertions in the active-core RTL/testbench provide the
mechanism-to-check traceability; no new RTL or testbench was necessary.

## Limitations

- No formal SVA/property proof or coverage database is present; evidence is
  self-checking directed/integration simulation.
- The complete historic regression was not allowed to finish in this run,
  although the relevant focused tests passed.
- The KAN-47 and KAN-51 PowerShell wrappers require a working Python command
  for their report summariser; this does not affect the XSim pass/fail result.
- Waveform files exist from the summer verification work, but this task did
  not add a new screenshot because no new testbench was introduced.

## Assessment

**PASS.** All applicable RAW, forwarding and stall mechanisms for the active
CPU have reproducible self-checking XSim evidence. The remaining limitations
are reporting/tooling and formal-coverage limitations, not unverified
applicable hazard behaviour. KAN-64 is ready for review to transition to Done.
