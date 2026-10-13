# Next Architectural Bottleneck After DOT4ACC

## Purpose and traceability

This report consolidates the repository evidence requested for the next
architectural investigation after the existing DOT4ACC acceleration. It is
intended for supervisor discussion and does not implement or modify RTL,
benchmark programs, constraints, Jira issues, commits or pushed history.

Traceability:

- **KAN-69:** next-architecture investigation and research hypothesis.
- **KAN-360:** completed DOT4ACC scaling and operand-delivery/frontend profile;
  commit `7041824` is the current branch head.
- **KAN-365:** proposed follow-on Variant A evaluation. No Jira-specific
  source artifact or commit carrying the KAN-365 key was found in this
  checkout, so this report does not claim that KAN-365 work is already
  implemented.

The repository does not contain Jira metadata for KAN-69 or KAN-365. Their
mapping above is therefore a work-item traceability label supplied by the
task, not an inferred Jira title.

## 1. Reproduced DOT4ACC Conv2 benchmark

The frozen benchmark is the branch-free packed program in
`reports/dot4acc_conv2_profile/`, using the active core
`rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`. It computes four
outputs from 36 useful signed INT8 MAC-equivalent products. The specialised
program uses three DOT4ACC operations per output, with zero-padded lanes where
necessary.

Command reproduced on 13 October 2026 with Vivado/XSim 2026.1:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File reports/dot4acc_conv2_profile/run_profile.ps1
```

Result:

| Metric | Reproduced result |
|---|---:|
| Total cycles | 232 |
| Retired instructions | 207 |
| DOT4ACC instructions | 12 |
| Output check | PASS; `[-116, 15, -97, 90]` |
| Fetch-wait counter | 20 |
| Memory-wait counter | 0 |
| Data-hazard stalls | 0 |
| Load-use stalls | 0 |
| Control flushes | 0 |
| Pipeline-fill counter | 6 |

The raw run output is retained in
`reports/dot4acc_conv2_profile/` and the machine-readable breakdown is
`reports/dot4acc_conv2_profile/trace_summary.csv`.

### Retired-instruction breakdown

| Purpose | Count | Interpretation |
|---|---:|---|
| DOT4ACC computation | 12 | Three four-lane operations for each of four outputs; 48 lane slots, 36 useful products and 12 zero padding lanes |
| Operand loads | 24 | Two packed operand words per DOT4ACC operation group |
| Output/sentinel stores | 5 | Four output stores plus one completion sentinel store |
| Setup/address generation | 6 | ADDI instructions used for initial setup/address state in the specialised image |
| Dynamic packing | 0 | Activations/effective weights are pre-packed offline in `programs/kan50_conv2_tile_dot4acc_data.mem`; no runtime pack/unpack instruction exists |
| Branches and jumps | 0 | Program is fully unrolled and branch-free |
| Other scalar arithmetic | 0 | No ADD/SUB arithmetic in the specialised kernel |
| Scheduled NOPs | 160 | Deliberate spacing for the current synchronous load/DOT issue schedule; these are retired instructions and must be included |
| **Total** | **207** | `12 + 24 + 5 + 6 + 160` |

The benchmark therefore already removes scalar multiplication, loop control
and runtime packing. The remaining instruction stream is dominated by safe
operand-delivery spacing, not useful arithmetic.

## 2. Cycle explanation

The direct cycle relationship is:

`232 total cycles - 207 retired instructions = 25 cycles beyond the retired-instruction count`.

Twenty of those cycles are explicitly reported as instruction-fetch waits.
The remaining five are not exposed as a causal category by the frozen
counter interface. The six-cycle pipeline-fill counter cannot be subtracted
as a disjoint category because the counters are event-based and can overlap
retirement or frontend transitions. Similarly, fetch-wait events do not form
a complete per-cycle partition.

The defensible interpretation is therefore:

- **20 cycles:** measured fetch-wait events.
- **5 cycles:** unclassified startup, response alignment, retirement/drain or
  event-accounting difference.
- **6 fill cycles:** a related pipeline metric, not an additional six cycles
  to add to the 25-cycle residual.
- **0 cycles:** measured data-memory wait, load-use/data hazard and control
  flush counters.

The current evidence does not support assigning the five residual cycles to
memory latency, DOT arithmetic, or hazards. A future simulation-only trace
should classify each enabled clock by frontend response, load hold, DOT issue,
DOT completion, retirement, reset/flush and other.

## 3. Workload scaling evidence

The completed KAN-360 dynamic profile is reproduced with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File reports/dot4acc_dynamic_profile/run_profile.ps1
```

All cases produced the expected result. The scaling sweep is:

| Workload | Useful MACs | Cycles | Retired | DOT4ACC | Loads | Stores | Fetch waits | Memory waits | Hazard/load-use | Cycles/MAC |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Small | 16 | 39 | 13 | 4 | 8 | 1 | 15 | 1 | 1 / 1 | 2.4375 |
| Medium | 64 | 135 | 49 | 16 | 32 | 1 | 51 | 1 | 1 / 1 | 2.1094 |
| Large | 128 | 263 | 97 | 32 | 64 | 1 | 99 | 1 | 1 / 1 | 2.0547 |

The exact measured relationship for the combined memory-fed kernel is:

`cycles = 7 + 8 × DOT_groups`

and the fetch-wait relationship is approximately:

`fetch_waits = 3 + 3 × DOT_groups`.

The register-resident microbenchmark provides the control comparison:

`cycles = 11 + 1 × DOT_groups`.

The load-only stream is approximately three cycles per group. Consequently,
the combined load/load/DOT path costs roughly eight cycles per group, while
resident DOT4ACC itself scales at roughly one cycle per DOT. The four-cycle
per-group interaction beyond the standalone load and resident-DOT paths is
the strongest evidence for an operand-loading/frontend/issue interaction.

### Bottlenecks that persist across sizes

1. **Operand delivery and frontend/DOT issue scheduling persist and scale.**
   Fetch waits grow from 15 to 99 and the combined slope remains about eight
   cycles per DOT group.
2. **DOT arithmetic is not the primary scaling bottleneck.** Resident DOT
   execution has an approximately one-cycle-per-DOT slope.
3. **Memory latency is not shown to scale.** Memory waits remain at one in all
   three measured combined workloads.
4. **Hazards are not shown to scale.** Data-hazard and load-use counters remain
   fixed at one, with no branches or jumps in the packed sweep.
5. **The Conv2-specific 160 NOP schedule is a real short-kernel cost.** It is
   not present in the compact scaling sweep in the same form, but it confirms
   that instruction scheduling and operand timing can dominate after compute
   compression.

The evidence supports a fused or streaming operand-delivery investigation. It
does not support a standalone cache, DMA engine or scratchpad as the next
change.

## 4. Accelerator interface comparison

The distinctions below separate repository measurements from documented
capabilities and from unexecuted external configurations.

| Aspect | Existing custom CPU | PicoRV32 PCPI | MicroBlaze V |
|---|---|---|---|
| Current evidence | Direct RTL, XSim and Basys 3 implementation evidence | Measured local reference exists, but with PCPI disabled | Block design/XSA validated; execution and synthesis performance incomplete |
| Normal accelerator hook | Direct opcode and private DOT issue/completion path | PCPI valid/ready coprocessor interface for non-branching custom operations | Four GET/PUT custom stream instructions and AXI4-Stream/system integration |
| Operand delivery | Register operands plus dedicated DOT metadata/BRAM path | Coprocessor receives decoded instruction and source operands; larger buffering requires a wrapper/memory interface | Stream or AXI-connected accelerator is the natural integration model; execute-stage RTL is vendor IP |
| Completion model | Custom fixed pipeline, dependency holds, retirement and cancellation logic | PCPI can hold the core with `wait` and complete with `ready`/`wr`/`rd` | Vendor-defined stream/accelerator protocol; no local DOT4ACC-like implementation in this repository |
| Native packed INT8/DOT4ACC | Yes: four signed INT8 lanes and accumulation | No native packed MAC in the tested configuration; PCPI/custom extension would be required | No native four-lane INT8 DOT4ACC identified in the repository evidence |
| Measured local result | Conv2 DOT4ACC: 232 cycles, exact output | N=128 hardware-MUL scalar: 8,208 cycles, exact output; not a PCPI accelerator result | No cycle or instruction result claimed |
| Resource evidence | 2,008 LUT, 1,812 FF, 5 DSP48E1, 2 RAMB18 at 93 MHz | 10,006 LUT, 869 FF, 0 DSP, 0 BRAM for an experiment-local LUTRAM wrapper; not directly comparable | AMD published configurations exist, but local comparable resource result is not complete |

PicoRV32 is therefore a useful open RTL integration reference, but its
measured comparison used `ENABLE_PCPI=0`, `ENABLE_MUL=1` and
`ENABLE_FAST_MUL=0`; it does not measure a PCPI accelerator. Its documented
PCPI capability supports the architectural comparison only.

MicroBlaze V is a documented vendor-supported RISC-V soft processor with
configurable pipeline choices, local memory, performance counters and
stream/AXI integration options. The local experiment uses
`xilinx.com:ip:microblaze_riscv:1.0` and exported an XSA, but Vitis/HSI and
bounded XSim/synthesis execution did not yield a completed performance result.
No MicroBlaze number should be used to rank the proposed Variant A.

The custom CPU remains the appropriate implementation platform because its
operand-delivery path, counters, ISA and accelerator RTL are directly
modifiable and measurable. PicoRV32 and MicroBlaze V are comparison points,
not substitutes for a same-device, same-wrapper Variant A experiment.

## 5. Candidate architectural improvements

| Candidate | Expected speed-up | Complexity | Resource overhead | Technical risk | Assessment |
|---|---|---|---|---|---|
| Fused load/load/DOT4ACC streaming command | Highest credible near-term; target reducing the measured 8-cycle group slope toward 4 or below | Medium-high | Low-medium: address counters, operand holding and command state; likely no new DSPs | Medium-high: BRAM timing, pause/flush, completion and precise retirement | **Rank 1**; directly targets the measured interaction |
| Operand-delivery frontend with prefetch/paired operand buffering | Medium-high if it removes fetch/spacing bubbles without changing DOT arithmetic | Medium | Low-medium LUT/FF and possibly BRAM registers | Medium: buffering, redirects and stale operands | **Rank 2**; smaller Variant A alternative |
| Zero-overhead loop/fused repeat control | Medium for regular loops; low for the already unrolled Conv2 DOT image | Medium | Low-medium | Medium: redirect, reset, nesting and flush interactions | Rank 3; more relevant to scalar or future tiled kernels |
| Additional DOT lanes | Low-medium for current memory-fed path because resident DOT is already 1 cycle/DOT | Medium-high | High DSP/routing cost | High timing/resource risk | Rank 4; not justified before operand delivery |
| Banked scratchpad | Unknown/low standalone benefit; memory waits are constant at one | Medium-high | Medium-high BRAM and banking logic | Medium-high bank conflicts and software contract | Rank 5; needs new memory-stall evidence |
| DMA/double buffering | Potentially high only for larger external-memory workloads | High | Medium-high control/BRAM/AXI overhead | High integration and setup risk | Rank 6; unsupported for current on-chip benchmark |
| Dedicated 3x3 convolution engine | Potentially highest on matching large tiles | Very high | High DSP/BRAM/control cost | High generality and boundary-case risk | Rank 7; too specialised as the immediate next experiment |
| Full lightweight vector extension | Potentially high across varied workloads | Very high | High register/control/routing cost | High ISA/toolchain/verification risk | Rank 8; disproportionate to current evidence |

The ranking uses end-to-end cycles as the primary metric. Peak MACs/cycle
alone is insufficient because the existing experiment demonstrates that
operand and instruction delivery can dominate a four-lane arithmetic unit.

## 6. Recommended Variant A

**Variant A: bounded streaming DOT4ACC operand-delivery command.**

The first implementation candidate should reuse the existing four-lane
DOT4ACC arithmetic and add only a bounded command/operand-delivery layer. A
command would specify two packed operand bases, a DOT-group count and an
accumulator/output destination. Internal address counters and two operand
holding registers would issue the existing DOT operation repeatedly, with an
explicit busy/done or retirement-visible completion protocol. The first
experiment should not add DMA, external memory, double buffering or more DSP
lanes.

This is deliberately a research variant, not an approved RTL design. Before
implementation it needs an interface specification covering reset, enable
freeze, branch/flush cancellation, x0, output visibility, memory bounds,
signedness, partial groups, and exact-once completion.

Why this variant is evidence-based:

- It attacks the measured combined slope of eight cycles/DOT group.
- It targets the three-fetch-wait-cycles-per-group trend.
- It preserves the resident DOT arithmetic path already shown to reach about
  one cycle/DOT.
- It avoids claiming that zero measured memory waits require a new memory
  hierarchy.
- It can be compared against the existing scalar Conv2, 232-cycle DOT4ACC
  Conv2, and 39/135/263-cycle size sweep without changing the baseline.

## 7. Testable research hypothesis

> **H1 (KAN-69/KAN-365):** On the existing Basys 3/Vivado 2026.1 platform,
> a bounded streaming operand-delivery command that reuses the existing
> four-lane DOT4ACC arithmetic will reduce the memory-fed DOT4ACC kernel slope
> from approximately 8 cycles per DOT group to 4 cycles per group or less,
> while preserving exact outputs, keeping measured memory waits non-growing,
> maintaining at least 93 MHz timing closure, and using no more than two
> additional DSP48E1 sites and one additional BRAM tile.

Primary acceptance measurements:

- N=16, 64 and 128 exact output checks pass.
- Total cycles and cycles/DOT group are reported for resident, load-only and
  combined cases.
- The combined slope is calculated from all three sizes, not a single run.
- Fetch waits, memory waits, hazard stalls, load-use stalls and completion
  events are recorded.
- The implementation meets 93 MHz timing and reports LUT/FF/DSP/BRAM deltas.
- Existing Conv2 remains reproducible at 232 cycles before comparison, and
  any Variant A Conv2 result is reported separately.

A failure to reduce the slope, or a timing/resource regression, would falsify
the hypothesis and provide evidence to revisit a smaller operand buffer or a
software/control-only variant. It would not justify silently changing the
baseline.

## 8. Evidence gaps and next safe steps

The principal missing evidence is a disjoint cycle-reason trace. Current
counters show correlation but not causation: fetch waits, fill, retirement and
hold events are not an additive partition. Before RTL work, add a
simulation-only trace or testbench-side stage-valid classifier for the frozen
core, then model Variant A command timing against the same trace.

Other limitations:

- Runtime packing cost is absent from the current DOT4ACC image because data
  is pre-packed offline.
- The Conv2 result is a strong same-CPU acceleration result, not a general
  comparison against a mature RISC-V processor.
- PicoRV32 PCPI capability is documented but was not measured in the local
  comparison.
- MicroBlaze V accelerator integration is documented and its hardware platform
  was prepared, but no completed local performance result exists.
- The current 256-word BRAM model limits conclusions about much larger CNNs;
  the size sweep is useful for scaling the repeated kernel, not full-network
  external-memory behavior.

## Repository evidence index

- `reports/dot4acc_conv2_profile/DOT4ACC_Conv2_profile.md`
- `reports/dot4acc_conv2_profile/run_profile.ps1`
- `reports/dot4acc_conv2_profile/trace_summary.csv`
- `reports/dot4acc_dynamic_profile/DOT4ACC_dynamic_profile.md`
- `reports/dot4acc_dynamic_profile/run_profile.ps1`
- `reports/dot4acc_microbench/DOT4ACC_microbench_analysis.md`
- `reports/dot4acc_microbench/results.csv`
- `reports/baseline_cnn_workload_profile/baseline_cnn_workload_profile.md`
- `reports/kan357_ai_acceleration_review/KAN-357_ai_acceleration_review.md`
- `docs/fyp/platform_comparison.md`
- `docs/fyp/processor_empirical_comparison.md`
- `experiments/processor_empirical_comparison/platform_decision.md`
- `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
