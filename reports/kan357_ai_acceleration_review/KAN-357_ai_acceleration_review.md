# KAN-357 — Review of AI Acceleration Approaches for Lightweight Processors

**Status:** Research and synthesis complete; no architecture selected.

**Date:** 2026-10-08  
**Repository commit reviewed:** `020c3279e1b9770c4c361dd8ea0fe769b2e4fcaf` (`fyp-stage4-evidence-freeze`)  
**Baseline tag:** `fyp-stage3-baseline` at `f6b25ca196493858cc2b501a0324c4a794c0dd94`

## 1. Purpose and scope

This review surveys practical mechanisms for accelerating INT8-style AI kernels in or beside a small FPGA soft processor. It is an input to KAN-358. It does not choose an architecture, modify the ISA, or claim that a literature result transfers directly to this CPU.

The review covers custom instructions, packed/SIMD execution, tightly coupled MAC or dot-product units, small convolution engines, scratchpads, DMA and double buffering, lightweight vectors, and loop/control acceleration. The comparison is deliberately critical: an approach is useful only if it addresses the measured bottleneck at acceptable FPGA area, timing, software and verification cost.

## 2. Frozen baseline context

The frozen representative workload is a scalar software Conv2-derived INT8 tile: four outputs and nine products per output, or 36 useful MAC-equivalent operations. It runs on a Basys 3 (`xc7a35tcpg236-1`) at a validated 93 MHz.

| Metric | Frozen S4 baseline |
|---|---:|
| Cycles | 1,464 |
| Retired instructions | 962 |
| CPI | 1.5218295 |
| Instructions/MAC | 26.7222222 |
| Cycles/MAC | 40.6666667 |
| LUT / FF | 2,008 / 1,812 |
| DSP / BRAM tiles | 5 / 1 |
| Total power estimate | 0.086 W |
| Total energy/workload | 1.353806 µJ |

KAN-62 identifies scalar instruction-count and branch/control-flow overhead as dominant. The profile contains 216 conditional branches, 151 unconditional jumps, 144 loop-counter updates, 265 ADDI instructions, 216 scalar ADD/SUB instructions and 114 load/store instructions. It measured 216 control-flush cycles, zero memory-wait cycles, zero data-hazard stalls and zero load-use stalls. There are 280 excess cycles not assigned to a measured cause. Therefore “many memory instructions” must not be treated as equivalent to “memory stalls”.

The physically present DOT4ACC/MAC8 path is not issued by this scalar benchmark. Its presence is evidence of an available implementation direction, not evidence of achieved workload acceleration.

## 3. Review methodology

The sources prioritise ISA specifications, processor/accelerator documentation, FPGA vendor documentation, and peer-reviewed or research-group papers. Each class was assessed against: instruction and control reduction; operand delivery; datapath, register-file and pipeline changes; DSP/BRAM/LUT/FF pressure; software/toolchain impact; INT8 suitability; and verification risk. Ratings in the companion matrix are qualitative and mean relative to this small baseline, not universal hardware costs.

## 4. AI-specific instruction extensions

Custom MAC, dot-product, packed multiply-accumulate and convolution-oriented instructions can replace a sequence of scalar loads, multiplies, adds, pointer updates and loop checks with one or a few architecturally visible operations. A scalar custom instruction is the smallest integration step; a custom coprocessor interface can instead launch a multi-cycle operation and return a result later. RISC-V reserves custom opcode spaces, while RoCC-style interfaces demonstrate a command/response path for tightly coupled accelerators [R1, R2].

For this baseline, a dot-product instruction is strongly motivated by the 26.72 instructions/MAC and the 367 branch/jump instructions. A four-lane INT8 dot product could reduce arithmetic and some load/loop instructions, but only if operands can be delivered in packed form and software can issue it regularly. A fused instruction does not automatically remove branches: the surrounding loop, address arithmetic and termination code may remain.

Datapath changes include signed INT8 unpacking, parallel multipliers, widening accumulation, saturation/rounding policy if required, and an execution-unit result path. The register file may remain 32-bit if four bytes are packed per operand, but byte extraction and accumulator width must be specified. A multi-cycle unit needs valid/ready or a fixed latency, stall/scoreboard behaviour, forwarding rules, and reset/pause semantics. These are material verification additions for a pipelined core.

On Basys 3, DSP48E1 slices natively support multiplication, addition and accumulation, so a MAC can map efficiently to DSPs; multiple narrow operations may or may not pack efficiently into the available slice structure [R7, R8]. The cost is not only DSP count: decode, operand muxing, forwarding and control can consume LUT/FF and reduce Fmax. Compiler support can range from an intrinsic/assembly sequence to instruction-selection patterns; without it, the feature may be useful only to a hand-written kernel.

**Critical limitation:** one MAC instruction addresses arithmetic and instruction count, but a single result per instruction may leave the 216 control flushes substantially intact. A custom instruction is therefore credible, but its benefit must be measured as total cycles and instructions, not MAC throughput alone.

## 5. SIMD / packed-data execution

Packed SIMD treats a scalar register as multiple low-precision lanes. Four signed INT8 lanes in a 32-bit register are a natural fit for this CPU. PULP’s XPULP examples show packed SIMD, post-increment loads and MAC instructions being combined for dot products; its documented example reports lower instruction and cycle counts for a four-way INT8 dot product [R4]. The RISC-V P extension is a useful specification reference for fixed-point packed operations in integer registers, while the standard V extension adds 32 vector registers, vector CSRs and implementation-defined VLEN/ELEN parameters [R2, R3].

Packed execution can provide up to four 8-bit multiplies per issue, but “four operations/instruction” is an upper bound, not a workload result. It requires packing/alignment conventions, signedness rules, accumulator widening and possibly horizontal reduction. Loads may need byte-lane rearrangement; unpacking or repacking can erase the gain for short or irregular loops. Register pressure rises because packed values and partial accumulators coexist, while a true vector extension also adds a vector register file, CSRs, context state and more complex compiler obligations.

SIMD can reduce loop iterations and arithmetic instructions, and may reduce branch frequency when one instruction covers multiple products. It does not by itself remove all address generation or branch flushes. Its FPGA cost is implementation-dependent: narrow multipliers may use DSPs or LUTs, and parallel lane wiring can affect timing. For the current 4-product grouping, a small packed-dot instruction is more proportionate than a full V-like implementation; this is a candidate direction, not a selection.

## 6. Tightly coupled MAC or dot-product units

A tightly coupled unit can accept source registers and either return a result in a fixed number of cycles or expose a busy/ready protocol. A one-cycle MAC resembles an execution-unit extension. A streaming dot-product engine can accept a start/configure instruction, read a bounded operand region, accumulate internally and signal completion. Gemmini is a representative research example of a full-stack, configurable systolic/DNN accelerator integrated with a RISC-V system [R5]. RoCC and newer extension interfaces illustrate why operand transport, decoupled completion and software-visible command semantics matter [R1, R6].

The main advantage over a simple MAC instruction is amortisation: one launch can cover many products and loop operations. It can therefore address arithmetic, instruction count and potentially control overhead. The main risk is operand delivery. If every product still requires a scalar load and issue handshake, the unit becomes a faster arithmetic island behind the same control bottleneck. An internal accumulator and local operand ports improve throughput but introduce storage, address sequencing, pause/resume, exception and exactly-once completion cases.

For this CPU, the smallest credible unit would likely be a bounded INT8 dot product with explicit start and completion semantics. A larger coprocessor is more general but increases integration and verification scope. DSP use is proportional to parallel lanes; BRAM use appears if operands or partial sums are buffered. The current zero memory-wait result makes a memory-stalling coprocessor hypothesis weak, but instruction/control offload remains plausible.

## 7. Dedicated convolution acceleration

A small 3x3 convolution engine can retain weights, reuse input windows and generate several output pixels per command. Line buffers, sliding-window registers and a small MAC array reduce repeated address generation and expose spatial reuse. Eyeriss is a large research reference: its row-stationary dataflow explicitly targets local reuse and data-movement energy, with a 168-PE spatial architecture [R9, R10]. It demonstrates the principle, not a suitable size for this project.

A small semi-systolic or fixed-window unit could turn the four-output, nine-product tile into a bounded accelerator transaction. It may remove most scalar loads, address updates, branches and arithmetic instructions from the CPU trace. However, setup, output-format, padding, stride, channel and tile-boundary handling can dominate a tiny 36-MAC workload. A fixed 3x3 unit also has low generality outside matching convolutions; a reusable dot-product engine is more broadly applicable.

The likely FPGA cost is several DSPs plus line-buffer BRAM/LUTRAM, control FSMs, input packing and an interface to the CPU or local memory. Timing risk comes from fanout, reduction trees and routing between MACs. Verification must cover window alignment, signed arithmetic, accumulation width, stalls, reset, partial tiles and equivalence with the scalar golden result. The class is research-relevant because it directly targets convolution, but its generality and setup overhead must be quantified rather than assumed away.

## 8. Scratchpads and local buffering

Scratchpads are software-managed local memories; banked scratchpads add parallel ports/banks for operand delivery. They can improve reuse and predictable bandwidth when the working set is reused and the external/shared memory path is limiting. Research on DNN scratchpads reports large reductions in off-chip accesses or latency when memory placement is effective [R11, R12].

The baseline has 114 load/store instructions but zero measured memory-wait cycles. The strong evidence is therefore only that address and memory instructions consume code space and issue slots; there is no evidence that the memory system is stalling the pipeline. A scratchpad could still help indirectly by enabling packed/burst-like operand access or by changing an accelerator interface, but a claim of direct latency improvement for S4 is unsupported until a counter or controlled experiment shows it.

Costs include BRAM tiles, banking/address logic, software-managed transfers, bank conflicts, capacity limits and a new memory-consistency contract between scalar code and an accelerator. A scratchpad paired with a MAC engine is more credible than a scratchpad alone. The experiment must isolate reduced memory instructions from reduced memory stalls.

## 9. DMA and double buffering

DMA moves blocks without one CPU instruction per word; double buffering overlaps transfer of one tile with computation on another. AMD’s AXI DMA documentation distinguishes simple mode from descriptor-based scatter/gather and shows that setup requires programmed channel/descriptors [R13, R14]. PULP’s DSP material likewise presents DMA as useful when data must move between larger L2 and smaller L1 memories [R4].

DMA is weakly justified for the current tiny representative tile: memory waits are zero, the workload is only 36 MAC-equivalent operations, and descriptor/setup overhead may exceed the CPU work saved. Double buffering cannot create useful overlap if there is no independent transfer latency to hide. This is not evidence that DMA is useless generally. Larger tiles, multiple channels, external memory, or a faster compute engine could make transfer time dominant; in that regime DMA plus scratchpad can reduce CPU copy/address instructions and overlap movement with compute.

The failure mode is adding a substantial control plane, descriptors, interrupts or arbitration without reducing end-to-end cycles. KAN-358 should use a size sweep and report setup amortisation, not extrapolate from the tiny S4 tile.

## 10. Lightweight vector extensions

Small vectors provide a programmable middle ground between scalar custom instructions and a fixed convolution engine. The RISC-V V specification supports data-parallel execution with implementation-defined VLEN and 32 vector registers; embedded Zve variants constrain the feature set and minimum vector length [R3]. Arrow is a research example of a configurable RISC-V vector accelerator aimed at edge ML inference and reports FPGA comparisons against scalar execution [R15].

A short vector length such as 32 or 64 bits could express packed INT8 arithmetic while retaining some programmability. A longer vector or full vector ISA adds vector register state, vector-length configuration, masking, precise traps and compiler/runtime obligations. Vector loops can reduce branches and loop-counter updates, but vector setup and tail handling are non-trivial for small tiles. A vector unit may also consume more LUT/FF and routing than the current 2,008-LUT baseline and can hurt timing.

This class remains plausible for larger and more varied AI workloads, but a full vector architecture may exceed the scope of a lightweight single-core FPGA study. A narrow vector-like dot-product subset is a more proportionate comparison point than implementing all of V.

## 11. Loop/control-flow acceleration

Hardware loops, repeat instructions, loop buffers and fused loop-and-compute operations directly target control overhead. A zero-overhead loop controller can maintain loop bounds and redirect the PC without executing a branch/counter sequence; research has reported improvements across embedded benchmarks, although those results are workload- and implementation-specific [R16, R17]. PULP examples combine hardware loops with post-increment loads and packed MACs [R4].

The S4 evidence makes this class unusually relevant: 216 conditional branches, 151 jumps, 144 loop-counter updates and 216 measured control-flush cycles. A hardware loop could plausibly remove loop-counter instructions and predictable back-edge branches, reducing both instruction count and some flushes. It may not remove unconditional jumps used for function/control structure, data-dependent branches, or all 280 unclassified cycles. The strongest hypothesis is as a secondary feature alongside compute acceleration, unless a trace confirms that the hot loops are regular and bounded.

Implementation is comparatively small—loop start/end/count state and fetch redirect logic—but correctness risk is concentrated in nesting, interrupts, reset, pause/resume, taken exits and interaction with existing pipeline flushes. A loop buffer can reduce fetch/control activity but adds storage and replacement rules. A fused loop-and-compute instruction may be powerful but becomes a domain-specific ISA change.

## 12. Cross-comparison

The qualitative comparison is in `acceleration_classes.csv`. In summary, custom low-precision instructions and tightly coupled dot-product units have the clearest direct path to reducing the 26.72 instructions/MAC. Packed SIMD offers multiple operations per issue but needs packing and lane semantics. Loop/control support is directly supported by the branch/flush evidence and may be a relatively small addition. Dedicated convolution engines can offer the largest tile-level reduction but sacrifice generality and may have setup overhead. Scratchpads and DMA are conditional on a future data-delivery bottleneck, not established S4 needs. Full lightweight vectors are flexible but carry disproportionate architectural and software scope unless kept narrow.

## 13. Applicability to the measured baseline

**Strong evidence:** scalar instruction count and control flow are the dominant measured problems. Approaches that replace multiple scalar arithmetic, pointer and loop instructions with one packed/dot-product command are directly motivated. The measured 216 control-flush cycles make hardware loops or fused repeated operations directly relevant. The existing DSP/BRAM budget provides a concrete FPGA cost baseline.

**Plausible but indirect:** a local operand buffer, scratchpad or internal accelerator buffer could reduce instruction traffic or support wider operand delivery, but it does not follow from zero memory waits that it will reduce cycles. A dedicated convolution engine is plausible because the workload is convolutional, but its benefit depends on launch and tile-boundary overhead.

**Unsupported speculation at present:** claiming that DMA, more BRAM, cache-like buffering or higher memory bandwidth will improve S4; claiming that the 280 residual cycles have a known cause; claiming that a full vector ISA is proportionate; or claiming that the physically present DOT4ACC/MAC8 hardware already accelerates the scalar benchmark.

## 14. Open questions for KAN-358

1. What fraction of the 367 branch/jump instructions belongs to regular inner loops, and how many can a hardware loop legally eliminate?
2. Can four signed INT8 operands be packed without extra loads/repacking for the actual memory layout?
3. What accumulator width, saturation and signedness semantics preserve the frozen golden output?
4. Does a one-cycle/fixed-latency dot instruction close timing at or above 93 MHz with acceptable DSP/LUT cost?
5. Is a start/complete dot engine faster end-to-end than a packed instruction once launch and result visibility are counted?
6. Does a small convolution engine amortise setup on the 36-MAC tile, and how does that change with larger tiles/channels?
7. What evidence would demonstrate a future memory-delivery bottleneck before adding scratchpad or DMA?
8. Can software/compiler support be kept to intrinsics or a small assembler library, and how will reference-model verification be maintained?

## 15. Conclusions for KAN-358

The review does not select the final architecture. It identifies the following 3–5 classes for direct quantitative comparison:

1. **Custom low-precision MAC/dot-product instructions** remain credible because they directly attack scalar arithmetic and the high instructions/MAC ratio. Main risk: decode, forwarding, accumulator semantics and software mapping. Quantify end-to-end cycles, instructions, DSP/LUT/FF, Fmax and verification scope.
2. **Packed INT8/SIMD execution** remains credible because four lanes can match the natural 32-bit register width and can reduce arithmetic and loop iterations. Main risk: packing, register pressure, lane wiring and timing. Quantify useful operations per issue and packing overhead.
3. **Tightly coupled MAC/dot-product execution unit** remains credible because one command could amortise control and address overhead beyond a single MAC. Main risk: operand delivery and multi-cycle handshake/pause correctness. Quantify launch amortisation, throughput, storage and CPU idle/overlap cycles.
4. **Loop/control-flow acceleration** remains credible because the measured profile contains 216 conditional branches, 151 jumps, 144 loop updates and 216 control flushes. Main risk: redirect/flush corner cases and limited benefit for irregular control. Quantify eliminated instructions and flush cycles from a trace-guided model.
5. **Small convolution engine** remains credible because it directly matches the workload’s 3x3 reuse pattern and can offload control. Main risk: specialisation and setup cost on a tiny tile. Quantify tile-size crossover, generality and total FPGA/power cost.

Scratchpad/local buffering and DMA/double buffering remain comparison options for larger-workload scenarios, but they should not be promoted to primary S4 candidates without new data-delivery evidence. A lightweight vector extension is a useful broader alternative, while a full vector implementation should be treated as a scope and toolchain risk.

