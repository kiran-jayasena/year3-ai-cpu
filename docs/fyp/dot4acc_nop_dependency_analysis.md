# DOT4ACC NOP Dependency Analysis

## Scope

This analysis compares the frozen branch-free Conv2 image with isolated
schedule variants. The RTL and original benchmark were not modified.

Active RTL:

`rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`

Relevant baseline image:

`programs/kan50_conv2_tile_dot4acc_scheduled.mem`

The original image has 24 LOAD instructions and 12 DOT4ACC instructions. Its
NOP runs are:

- 20 load-to-load gaps of six NOPs;
- 4 final-load-to-DOT-chain gaps of ten NOPs;
- total: `20*6 + 4*10 = 160` scheduled NOPs.

## Pipeline facts

The scalar path has fetch buffering, IF/ID, ID/EX, EX/MEM and MEM/WB/retirement
boundaries. Instruction and data memories are synchronous BRAM-style memories.
The data-memory read is registered, and the active core has explicit
load-use detection for `rs1`, `rs2` and the accumulator role.

DOT4ACC is admitted from ID/EX into a private issue/completion path. Its
metadata advances through the DOT pipeline, with dependency holds for
pre-completion source and accumulator destinations. Contiguous same-`rd`
chains use the DOT chain state and do not require software NOPs between DOT
instructions.

The tested Conv2 image has no LOAD-use counter events, no data-hazard events,
and no control redirects. Its schedule padding is therefore not explained by
the active hazard detector or by an observed stall counter.

## Dependency analysis

| Sequence | Original spacing | Minimum tested spacing | Evidence |
|---|---:|---:|---|
| LOAD followed by another LOAD | 6 NOPs | 0 NOPs | All 20 load-to-load gaps passed in `s0_d0`-style schedules |
| Final LOAD followed by DOT chain | 10 NOPs | 0 NOPs | All 4 load-to-DOT gaps passed with `s0_d0` |
| Consecutive DOT4ACC chain | 0 NOPs | 0 NOPs | Existing active-core chain tests and Conv2 schedule pass |
| DOT4ACC followed by STORE | 0 NOPs | 0 NOPs | Zero-NOP Conv2 output/sentinel checks pass |

The safe spacing result is empirical for this verified program family and
active core. It does not prove that arbitrary LOAD/DOT programs can omit all
spacing; a LOAD-use dependency may still require the RTL's normal one-cycle
stall when a consumer enters the relevant stage. The Conv2 schedule avoids
that hazard by the time the DOT operation is captured.

## Why the NOPs were originally inserted

The NOPs were conservative software schedule padding around synchronous
operand loads and the DOT issue path. They are not required for the tested
architectural output, accumulator chain, BRAM read result or instruction-fetch
counter behaviour. The current evidence indicates that they were introduced
by benchmark generation/scheduling assumptions rather than demonstrated
microarchitectural dependencies.

The NOPs also inflate the instruction image and retirement count. Removing
them does not alter the four packed data words, address immediates, DOT
operands, accumulation order or output stores.

## Limits of the conclusion

The experiment uses exact Conv2 inputs and four output elements. Wider
correctness is supplied by the inherited active-core architectural testbench,
which covers signed boundaries, zero, overflow/wraparound, chains, LOAD
dependencies, DOT-to-scalar consumers, reset and redirect behaviour. It does
not make the zero-spacing result a proof of all possible software schedules.

The correct conclusion is: **all 160 NOPs are safely removable from this
verified Conv2 image, and the minimum tested spacing is zero for both schedule
classes.**
