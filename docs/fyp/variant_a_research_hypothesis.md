# Variant A Research Hypothesis

## Revised hypothesis

> After correcting the Conv2 software schedule by removing its 160 redundant
> NOPs, a bounded streaming load/load/DOT4ACC command that reuses the existing
> four-lane arithmetic path will reduce the compact memory-fed workload slope
> below the measured 8 cycles per DOT group, while preserving exact numerical
> results, achieving at least 93 MHz timing closure, and adding no more than
> two DSP48E1 sites and one BRAM tile.

The hypothesis is deliberately relative to the fair compact baseline. It does
not credit Variant A for the 160-cycle Conv2 schedule correction.

## Falsifiable acceptance criteria

- Small/medium/large workloads pass exact output checks.
- The N=16/64/128 cycle fit has a slope below 8 cycles/DOT group.
- Fetch waits and memory waits are reported separately.
- No new uncontrolled hazard, reset, flush or completion error appears.
- The Conv2 NOP-optimised result remains 72 cycles without Variant A.
- Post-implementation timing is at least 93 MHz on the Basys 3 target.
- Resource deltas are measured rather than inferred and remain within the
  stated DSP/BRAM limits.

Failure of the slope criterion would reject the fused command as the next
architecture even if its arithmetic unit is functionally correct. Failure of
timing or resource criteria would favour a smaller operand-prefetch or control
variant.

## Method

1. Freeze the current RTL, compact workload images and 72-cycle Conv2 schedule
   result.
2. Specify the command and memory-port assumptions before RTL changes.
3. Build an interface-level golden model for address progression, signed lane
   arithmetic and accumulation.
4. Verify the isolated command with directed boundary, zero, negative,
   overflow and back-to-back cases.
5. Integrate it in a copied CPU path with exact-once completion, reset,
   enable-freeze, redirect and dependency tests.
6. Run the three workload sizes and the corrected Conv2 comparison.
7. Synthesize and implement on the same Basys 3/Vivado flow.

## Research contribution

The contribution is not merely a faster benchmark image. It is a controlled
comparison showing that software schedule padding can be removed completely,
then testing whether a hardware operand-delivery mechanism improves the
remaining size-dependent load/load/DOT interaction. This isolates inherited
software improvement from new microarchitectural improvement.
