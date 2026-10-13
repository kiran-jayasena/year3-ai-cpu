# Variant A Architecture Decision

## Decision

Select **Variant A: a bounded streaming load/load/DOT4ACC operand-delivery
command**, subject to supervisor approval and a separate RTL design phase.

Do not implement it in this investigation.

## Why scheduling alone is insufficient

The Conv2-specific 160 NOPs were all removable, reducing 232 cycles to 72.
However, the existing small/medium/large memory-fed tests already contain no
scheduled NOPs and still require 39, 135 and 263 cycles. Their measured slope
is approximately eight cycles per DOT group. Fetch waits grow with workload
size while memory and hazard counters remain fixed.

Thus the corrected software baseline removes an accidental Conv2 cost, but
the scalable operand-loading/frontend interaction remains.

## Options

| Option | Bottleneck addressed | Expected benefit | Cost/risk | Decision |
|---|---|---|---|---|
| A. Optimised software schedule | Conv2-only padding | 3.22x versus the original Conv2 image; no scaling benefit because KAN-360 was already compact | Minimal RTL risk; limited novelty | Necessary baseline, not sufficient Variant A |
| B. Small fetch/control or load-forwarding change | Frontend bubbles or selected dependencies | Uncertain; current zero-NOP sweep shows no Conv2 dependency bubble to remove | Medium RTL/verification/timing risk | Keep as fallback, not primary |
| C. Fused load/load/DOT4ACC command | Repeated operand delivery and DOT issue interaction | Highest evidence-supported hardware opportunity; target a lower than 8-cycle/DOT-group scaling slope | Medium-high interface, BRAM, flush and completion risk | **Select** |

## Provisional specification

The command should:

1. Accept two packed operand base addresses, a DOT-group count and an
   accumulator/output destination.
2. Generate the repeated operand addresses internally.
3. Capture two operand words and feed the existing four-lane DOT4ACC path.
4. Preserve signed INT8 lane order and modulo-2^32 accumulation semantics.
5. Expose busy/complete or retirement-visible completion exactly once.
6. Define behaviour for reset, global enable freeze, redirect cancellation,
   memory bounds, partial groups, x0 and output visibility.
7. Add no DMA, external memory protocol, extra DOT lanes or runtime packing in
   the first implementation.

The available data-memory port structure and BRAM read latency must be checked
before committing to a two-read-per-cycle design. A multi-cycle command that
overlaps address generation and operand capture may be more feasible than
assuming dual-port bandwidth.

## Evaluation and fallback

Compare against both corrected baselines:

- Conv2 original scheduled image: 232 cycles.
- Conv2 NOP-optimised image: 72 cycles.
- Compact scaling: 39/135/263 cycles for 16/64/128 MACs.

The minimum acceptable evidence is exact output equivalence, reduced scaling
slope, no new unbounded hazard behaviour, ≥93 MHz implementation timing and
resource deltas. If the command cannot improve the compact scaling slope
without violating timing or resource limits, fall back to a smaller
operand-prefetch/control experiment rather than adding DMA or a new MAC array.
