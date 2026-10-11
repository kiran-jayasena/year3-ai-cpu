# Platform decision

## Decision

**Retain the custom CPU as the Year III implementation platform, with
PicoRV32 as a measured external reference and MicroBlaze V as a hardware-
validated but execution-blocked architectural reference.**

The MicroBlaze V hardware design is validated and its fixed XSA is exported,
but its vendor-IP simulation and synthesis did not complete within bounded
timeouts. PicoRV32 has now produced a measured N=128 result, so the
cross-processor comparison is no longer wholly architectural; it remains
incomplete for MicroBlaze V.

## Evidence

- Custom CPU N=128 scalar: 6,155 cycles, 4,037 retired instructions, 0 fetch
  waits, 0 memory waits and 0 hazard stalls; exact output `0x00000240`.
- Custom CPU software-multiply accounting: 2,688 broad multiply-loop
  instructions, 66.5841% of retired instructions; this is a known ISA limit.
- Existing same-CPU references: MAC8 134 cycles and DOT4ACC 43 cycles,
  approximately 3.116x, retained as inherited evidence.
- PicoRV32 hardware-multiply primary: N=128 exact result, 8,208 cycles,
  899 retired instructions, 64.125 cycles/MAC and 7.0234 instructions/MAC.
- PicoRV32 same-part synthesis: 10,006 LUTs, 869 FFs, 0 DSPs, 0 BRAM tiles,
  WNS 2.567 ns at a 93 MHz constraint. These figures use an asynchronous
  LUTRAM memory wrapper and are not directly comparable with the custom
  BRAM-backed implementation.
- MicroBlaze V: block design validated and XSA exported for the requested part;
  Vitis/HSI software execution blocked; XSim elaboration and synthesis
  incomplete within bounded timeouts.

## Why the decision is unchanged

The custom CPU provides complete RTL visibility, deterministic counters,
reproducible local BRAM behavior, and direct control over MAC8/DOT4ACC and the
next Variant A change. Moving platforms would add BSP/toolchain/system risk
without producing a more controlled architectural experiment. The scalar
6.31x Conv2 claim remains baseline-dependent and must be qualified; MAC8 versus
DOT4ACC is the stronger controlled AI-acceleration comparison.

## Limitation

The PicoRV32 result is not a general processor-superiority claim: it uses a
different experiment-local memory timing model and LUTRAM rather than the
custom BRAM arrangement. It does show that the custom N=128 scalar result
(6,155 cycles, 48.0859 cycles/MAC) is not automatically worse than a realistic
lightweight RISC-V core in this bounded kernel. No MicroBlaze V performance
result was measured.
