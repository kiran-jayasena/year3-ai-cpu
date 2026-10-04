# KAN-51 instrumentation validation

## Scope

This validation checks counter semantics, controlled-program measurements, repeatability, and functional non-interference. It makes no performance-bottleneck interpretation.

## Counter semantics

- `total_cycles` increments once on each clock edge with `rst=0` and `enable=1`.
- `retired_instructions` increments once when a normal valid retirement, deferred-load retirement, or DOT completion retirement occurs.
- Reset clears both counters; disabled cycles increment neither.
- Reset and disabled startup cycles are therefore excluded from these externally bracketed measurements.
- Counters are direct RTL debug outputs, not software-readable CSRs or memory-mapped registers.
- Controlled measurements externally bracket execution with `enable` and stop at sentinel STORE retirement.
- Squashed/flushed instructions do not retire because they never reach a valid retirement event.
- Valid NOPs, arithmetic, branches, jumps, loads, stores, MAC8, and DOT completions are counted when they reach their respective retirement event.
- There is no separate trap counter or trap-retirement event in this core; no trap case is exercised by these tests.

## Results

| Test | Expected retired | Measured retired | Cycles | Runs | Stable | Functional | Result |
| --- | ---: | --- | --- | ---: | --- | --- | --- |
| straight_line_arithmetic | 6 | 6-6 | 11-11 | 5 | yes | PASS | PASS |
| fixed_count_loop | 14 | 14-14 | 26-26 | 5 | yes | PASS | PASS |
| taken_branch_control_flow | 5 | 5-5 | 13-13 | 5 | yes | PASS | PASS |
| load_store | 4 | 4-4 | 10-10 | 5 | yes | PASS | PASS |

Every controlled program was run five times inside each of two independent XSim invocations. Both raw CSV files were identical.

## Regression status

The existing H1.3b/T2 architectural testbench was rebuilt and run with Vivado XSim. It completed 4,254 checks with 0 failures; the full transcript is `focused_existing_core_regression.log`.

## Controlled-test interpretation

- Straight-line arithmetic retires six dynamic instructions, including the sentinel STORE.
- The three-iteration loop retires 14 instructions: two setup instructions, three iterations of increment/decrement/BEQ, two taken-path JUMPs, and one STORE.
- The taken branch test retires five instructions; the wrong-path ADDI is flushed and therefore excluded.
- The load/store test retires four instructions: base setup, LOAD, dependent ADDI, and STORE. Pipeline stalls affect cycles but not retired-instruction count.

## AI workload status

KAN-50 is not complete: Jira reports it as To Do and the repository contains no processor MNIST benchmark harness. No placeholder CNN cycle or retired-instruction result is reported. KAN-51 controlled validation is complete, but full KAN-51 closure remains gated on KAN-50.

The cycle and retired-instruction counters have been validated as stable and suitable for reproducible baseline measurement. No bottleneck interpretation is made in KAN-51; detailed performance analysis is deferred to S4.
