# Year III Experimental CPU Platform Comparison

## Executive conclusion

The custom CPU is a defensible Year III experimental platform, provided that
the report presents it as a transparent, application-specific research core,
not as a mature general-purpose soft processor. The recommended platform is:

> Keep the custom CPU as the implementation platform and use MicroBlaze V and
> PicoRV32 as external architectural references. Do not claim that the
> 6.31x Conv2 speed-up transfers to either reference processor.

The custom design is not unusually primitive in its basic pipeline organisation:
it has a 32-bit in-order pipeline, two register read ports, forwarding,
load-use handling, branch flushing, synchronous BRAM memories and explicit
retirement. It is unusually narrow in ISA breadth and system integration:
there is no scalar multiply, shift, byte extraction, cache, DMA, external
memory interface or standard software toolchain. That weakness can inflate a
custom-instruction speed-up if the scalar baseline is treated as a proxy for a
modern soft CPU.

The fair claim is therefore two-dimensional:

* Against the unchanged scalar custom-ISA Conv2 program, DOT4ACC measured
  1,464 to 232 cycles, or 6.31x, with exact outputs and zero memory-wait
  cycles.
* Against the same CPU's valid register-resident MAC8 implementation,
  DOT4ACC measured 134 to 43 cycles, or 3.116x, for the same 128 signed-int8
  products. This is a stronger control experiment, but it is not the same
  application workload.

The mature-core comparison should be framed as a fairness and research-value
assessment, not as a claim of superiority.

## A. Custom CPU architecture summary

### Evidence classification

| Classification | Repository evidence |
|---|---|
| Observed RTL fact | `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv` is the frozen active core; the top-level wrapper and Basys 3 constraints identify `xc7a35tcpg236-1`. |
| Observed RTL fact | 32-bit instructions; fields are opcode `[31:28]`, `rd [27:23]`, `rs1 [22:18]`, `rs2 [17:13]`, signed `imm13 [12:0]`; 32 registers and hardwired x0. |
| Observed RTL fact | Scalar pipeline uses fetch buffering, IF/ID, ID/EX, EX/MEM and MEM/WB/retirement boundaries. DOT4ACC has a separate three-stage advancing arithmetic path. |
| Observed RTL fact | EX/MEM and MEM/WB forwarding exists; a load-use bubble is inserted; DOT source and accumulator dependencies can hold issue; branch operands have a separate forwarding path. |
| Observed RTL fact | Taken BEQ/JUMP redirect and flush logic invalidates younger fetch/IF/ID/ID/EX work; pending redirects and DOT cancellation protect retirement. |
| Observed RTL fact | Register file is 32 x 32, two combinational reads, one synchronous write, x0 write-suppressed. |
| Observed RTL fact | Instruction and data memories are independent synchronous 256 x 32 arrays with `ram_style = "block"`; word selection uses `addr[9:2]`; aligned accesses are the defined use. |
| Observed RTL fact | ISA includes ADD, SUB, AND, OR, XOR, ADDI, LOAD, STORE, BEQ, JUMP, MAC8, DOT4ACC and NOP; reserved encodings are invalid. |
| Observed RTL fact | MAC8 is a scalar signed-low-byte multiply-add. DOT4ACC performs four signed-int8 products and an accumulator update; it is a pipelined custom instruction with same-destination chaining at II=1. |
| Observed RTL fact | Existing outputs expose retirement, retired instructions, data-hazard stalls, load-use stalls, control flushes, instruction-fetch waits, memory waits, branch direction, jumps and wrong-path flushes, plus DOT issue/completion/retirement and dependency observations. |
| Measured repository result | Frozen implementation is timing-clean at 93 MHz, PASS 5/5: 2,008 LUT, 1,812 FF, 5 DSP48E1, 2 RAMB18 (one BRAM tile), 1 BUFG, 0 latches; WNS +0.230 ns, TNS 0. A tested 94 MHz point failed. |
| Measured repository result | Scalar Conv2-derived benchmark: 1,464 cycles, 962 retired instructions, exact `[-116, 15, -97, 90]`, zero memory-wait, zero data-hazard, zero load-use and zero fetch-wait cycles. |
| Measured repository result | Existing DOT4ACC Conv2 run: 232 cycles, exact output, 6.31x cycle speed-up, zero memory-wait cycles. |
| Measured repository result | Other characterization: register-resident 128-product DOT4ACC is 43 cycles; memory-fed N=128 kernel is 263 cycles; complete J1 N=128 is 358 cycles at 93 MHz. |
| Inferred property | The datapath is single-issue and in-order: no RTL evidence of simultaneous retirement of two independent instructions or out-of-order issue was found. |
| Inferred property | MAC8 is intended to map to DSP hardware; the final post-route count shows five DSP48E1, but the report does not isolate how many DSPs are consumed by each arithmetic block. |
| Unknown | No direct apples-to-apples MicroBlaze/PicoRV32 implementation has been built in this repository. Their published resource and timing figures are not substitutes for a Basys 3 rebuild. |
| Unknown | No scalar-only post-route resource result exists for the final core; the 2,008-LUT/5-DSP result includes the DOT4ACC and MAC8 hardware even when the scalar benchmark does not issue them. |

### Architectural strengths

The CPU is a credible experimental object because its complete RTL is visible,
the instruction encoding is inspectable, custom arithmetic can be added without
an opaque vendor generator, and verification is unusually well instrumented for
a student soft core. The repository contains module-level self-checking tests,
full-program regressions, waveform artefacts, independent signed-int8 golden
models, timing sweeps and reproducibility scripts.

It also has a meaningful baseline hierarchy: scalar software, MAC8 and
four-lane DOT4ACC can be compared while holding the CPU, memories, clock target
and verification harness constant.

### Weaknesses relevant to fairness

The scalar ISA has no ordinary multiply, shift, byte extract or packed arithmetic
instruction. Consequently, the 1,464-cycle scalar Conv2 program uses repeated
addition/subtraction and substantial branch/address bookkeeping. That is a
legitimate measurement of this CPU's scalar baseline, but it is weaker than the
integer facilities normally available in the comparison processors.

The 256-word instruction and data memories, one register-file write port, one
deferred-load slot, no cache, no DMA and no external memory protocol constrain
large workloads and portability. The counters are useful but are not a
non-overlapping per-cycle partition: the 280 residual scalar cycles remain
unclassified in the repository's own profile.

## B. MicroBlaze V summary

MicroBlaze V is AMD's current RISC-V-based soft processor delivered with Vivado.
It is a strong engineering comparator because it is vendor-supported, has a
configuration wizard and software/debug ecosystem, and offers multiple pipeline
choices. AMD documents 3-stage area, 4-stage throughput, 5-stage performance
and 8-stage frequency-oriented pipelines. The 5-stage form is IF/OF/EX/MEM/WB;
the 3-stage form is Fetch/Decode/Execute. AMD documents forwarding/stalls,
branch penalties, instruction prefetch, LMB tightly coupled memory, optional
instruction/data caches and a branch target cache.

The relevant AI hooks are hardware integer multiply/divide options, DSP-capable
implementation presets, four GET/PUT custom stream instructions and AXI4-Stream
interfaces that can connect to an external accelerator. MicroBlaze V also has
base counters, up to 29 hardware performance-monitor event counters, optional
trace/profile buffers, hardware breakpoints and MDM debug support.

The limitation for this project is modifiability: the documented custom
instruction mechanism is a stream interface, not an invitation to edit the
processor's execute stage with arbitrary RTL. A DOT4ACC-like operation would
normally be a stream-connected accelerator or memory-mapped/AXI-connected unit,
not a small local opcode patch comparable to editing this repository's RTL.

## C. RISC-V reference summary: PicoRV32

PicoRV32 is selected as the compact open-source comparator. It is explicitly
FPGA-oriented, supports RV32I/RV32E/RV32IC/RV32IM/RV32IMC configurations, has a
native valid/ready memory interface plus AXI4-Lite and Wishbone variants, and
documents optional dual-port registers, cycle/time/instret counters, PCPI,
hardware multiply/divide and an optional trace output. Its documented CPI is
about 4 with one-cycle memory response; ALU register operations are about 3
cycles, loads/stores about 5, and the iterative MUL is 40 cycles. PCPI permits
non-branching custom coprocessor instructions and can return a result to the
decoded destination register.

PicoRV32 is a good experimental reference because the RTL is short enough to
read and modify, the interface is easy to wrap around BRAM, and its published
7-series data gives a useful scale point. The important risk is that the
repository was archived in September 2026 and is no longer actively developed.
That does not invalidate it as a stable comparator, but it weakens its value as
a current production platform. It is also not a superscalar or high-throughput
baseline: it is intentionally optimised for size and frequency rather than CPI.

## D. Side-by-side comparison matrix

| Criterion | Custom CPU | AMD/Xilinx MicroBlaze V | PicoRV32 |
|---|---|---|---|
| ISA | Custom 32-bit, 13 instructions incl. MAC8/DOT4ACC | RISC-V RV32/RV64 configurations, AMD options | RV32I/E/IC/IM/IMC configurations |
| Pipeline | Scalar five-boundary in-order plus 3-stage DOT path | Configurable 3/4/5/8-stage | Iterative multi-cycle core; no conventional fixed pipeline claim in the cited docs |
| Issue width | One instruction | One instruction; documented one completed/cycle absent hazards in pipelined forms | One instruction/transactional engine |
| Register file | 32 x 32, 2 read/1 write | RISC-V register file; configuration-dependent implementation | Dual-port or single-port selectable |
| Multiplier | MAC8 and DOT4ACC; no general scalar MUL | Optional hardware multiplier/divider | Optional iterative or fast MUL through PCPI |
| DSP use | Measured 5 DSP48E1 total, block attribution unknown | Published presets use 4 or 6 DSP48 on cited devices | Published area table does not report DSP use |
| MAC support | Native MAC8 and four-lane DOT4ACC | No equivalent native CNN MAC instruction identified; use MUL or accelerator | No native MAC; add PCPI/custom coprocessor |
| SIMD/packed arithmetic | DOT4ACC packs four signed INT8 lanes | No directly comparable packed INT8 instruction identified | No native SIMD; PCPI/custom extension possible |
| Custom instructions | Direct RTL opcode addition | Four GET/PUT stream custom instructions | PCPI custom coprocessor interface |
| Accelerator interface | Direct local RTL path; no standard bus | AXI4-Stream, AXI memory/system integration | PCPI; AXI4-Lite/Wishbone/native memory wrappers |
| Local memory | Two 256-word synchronous BRAM arrays | LMB tightly coupled memory, single-cycle local access | External memory system; local RAM/ROM straightforward via native interface |
| Cache | None | Optional I-cache and D-cache | No built-in cache in the cited core |
| Memory interface | Internal fixed BRAM arrays | Harvard, LMB and AXI interfaces | Valid/ready native, AXI4-Lite and Wishbone variants |
| Branch handling | BEQ/JUMP redirect, flush, pending redirect, no predictor | Pipeline stalls; optional branch target cache | Branch/control handled by core; no branch predictor claim used here |
| Profiling | Retire/stall/wait/branch/DOT counters and trace outputs | Counters, event/latency monitors, trace/profile buffers | RDCYCLE/RD TIME/RDINSTRET; optional trace |
| FPGA resources | Direct Basys 3 post-route: 2,008 LUT, 1,812 FF, 5 DSP, 2 RAMB18 | AMD published Artix-7 XC7A200T -3 presets: 573–8,730 LUT, 828–5,459 FF, 0/6/16 BRAM36, 0/4/6 DSP; not direct | Published 7-series area: 761/917/2,019 slice LUT and 442/583/1,085 registers for small/regular/large; not direct |
| Fmax | 93 MHz repeatably clean on Basys 3 -1; 94 MHz tested failure | AMD published Artix-7 XC7A200T -3: 94–232 MHz depending preset | Published Xilinx results: 416–769 MHz on other devices/speed grades; not Basys 3 comparable |
| Vendor compatibility | AMD/Xilinx Vivado, directly verified | Native Vivado IP | Vendor-neutral RTL; published Vivado 2017.3 flow |
| RTL availability | Full project RTL | Vendor IP, configurable but not open execute-stage RTL | Full Verilog RTL, ISC license |
| Documentation | Project-specific and traceable, limited ecosystem | Extensive official AMD manuals and tools | Strong README/RTL/tests, less formal than AMD; archival status |
| Debug/tool support | XSim, waveforms, custom counters, Git scripts | Vivado IP flow, GCC, debugger, MDM, trace/profile options | RISC-V GCC/binutils, tests, simulation, optional trace/formal ecosystem |
| Modification ease | Highest: local opcode and datapath visible | Lowest for execute-stage changes; high for attached accelerators | High: PCPI/wrapper, moderate for decode/RTL edits |
| Reproducibility | High within pinned Vivado/device/repo flow | High if Vivado/IP versions are pinned; vendor IP is opaque | High for RTL, but published synthesis is old and archived |
| CNN suitability | High for custom packed INT8 experiments; weak general software base | High system/integration baseline; custom arithmetic best as accelerator | Moderate control core; strong research hook through PCPI, not native CNN arithmetic |
| Final-year risk | Medium: architecture is frozen and known, but weak general ISA | Low integration risk, high custom-ISA risk | Low RTL integration risk, medium software/archive risk |

All published resource/frequency figures above are labelled non-directly
comparable. AMD's tables use other devices, speed grades and preset contents;
PicoRV32's tables use older Vivado and different Xilinx parts. No ratio of
these numbers to the custom CPU is methodologically justified.

## E. AI/DSP acceleration comparison

The custom CPU has a reasonable lightweight AI capability, not a complete CNN
platform. MAC8 provides one signed-int8 product per instruction. DOT4ACC provides
four packed signed-int8 products and an accumulate, with a three-stage arithmetic
pipeline and same-destination II=1. The 5-DSP post-route count demonstrates
real FPGA arithmetic mapping, although the exact DSP partition is unknown.

MicroBlaze V has a stronger general-purpose scalar base: optional hardware
multiply, standard RISC-V software support, local memory and caches. It has a
documented stream custom-instruction path and AXI4-Stream ports for accelerators,
so it can host a CNN engine cleanly. However, the available documentation does
not identify a native four-lane INT8 DOT4ACC operation. A fair implementation
would therefore compare an attached accelerator or a custom MicroBlaze
configuration, not pretend that base MicroBlaze scalar code equals DOT4ACC.

PicoRV32 has optional iterative/fast MUL and PCPI. PCPI is a natural place to
attach a non-branching dot-product unit, and its native/AXI interfaces make a
scratchpad wrapper practical. Its default scalar MUL is documented as 40 cycles,
so a CNN experiment would need fast MUL or a custom PCPI accelerator to avoid a
weak scalar reference. It has no native packed SIMD/MAC instruction.

Thus the custom CPU is not primitive in the narrow question of adding AI
arithmetic: its DOT4ACC path is more direct than either comparator's standard
instruction set. It is primitive as a general-purpose processor around that
path, especially in scalar multiply, memory system and software support.

## F. Quantitative comparison and limitations

### Direct measurements from this repository

| Measurement | Result |
|---|---:|
| Device/tool | Basys 3, `xc7a35tcpg236-1`, Vivado 2026.1 |
| Clean frequency | 93 MHz, five repeated passes |
| Resources | 2,008 LUT, 1,812 FF, 5 DSP48E1, 2 RAMB18, 1 BUFG |
| Scalar Conv2 | 1,464 cycles |
| DOT4ACC Conv2 | 232 cycles |
| Conv2 speed-up | 6.31x |
| DOT4ACC output correctness | Exact |
| Memory-wait cycles | 0 in both reported Conv2 runs |
| Register-resident 128-product MAC8 | 134 cycles |
| Register-resident 128-product DOT4ACC | 43 cycles |
| MAC8-to-DOT4ACC speed-up | 3.116x |

The Conv2 results are a cycle comparison at a common CPU and do not prove a
frequency-normalised advantage over MicroBlaze or PicoRV32. At 93 MHz, the
measured execution times are approximately 15.742 microseconds and 2.495
microseconds respectively. Those times are derived from the repository cycle
counts and the validated clock, not from a second FPGA implementation.

### Published external values

AMD's 2026.1 MicroBlaze V Artix-7 XC7A200T -3 table reports, depending on
preset, 573 to 8,730 LUT, 828 to 5,459 FF, 0/6/16 BRAM36 and 0/4/6 DSP, with
94 to 232 MHz. The custom CPU's -1 Basys 3 numbers must not be ranked directly
against that table.

PicoRV32 reports 761/917/2,019 slice LUT, 442/583/1,085 registers for
small/regular/large variants and 416–769 MHz on several other Xilinx devices.
Its resource numbers are area-optimised Vivado 2017.3 results and omit the
memories/system wrapper needed for a workload comparison. Its documented CPI
and MUL latency are useful analytical references only.

## G. Baseline fairness analysis

### Is the scalar CPU artificially weak?

Partly, yes. The scalar ISA lacks a general multiply and byte/shift operations,
so the scalar Conv2 program performs multiplication by repeated signed
addition/subtraction. MicroBlaze V and PicoRV32 can both be configured with a
standard hardware multiply, and both have richer base ISAs. Therefore 6.31x is
not a claim that DOT4ACC beats a well-configured general-purpose soft CPU by
6.31x.

But the scalar run is not invalid. It is the measured performance of the frozen
custom ISA, with the same memories, clock, output checks and program/data
definition. The report should call it “speed-up over the scalar custom-ISA
baseline,” not “speed-up over a conventional CPU.”

### Does existing DOT4ACC make the baseline stronger?

Yes. The chosen implementation already contains the accelerated datapath and
the benchmark deliberately disables it for the scalar run. Reporting only the
scalar comparison would hide the cost of the already inherited accelerator.
The 3.116x MAC8-vs-DOT4ACC control result and the 232-cycle application result
should both be retained.

### Would replacing the baseline with a mature processor change the question?

Yes. A MicroBlaze or PicoRV32 study would ask how an accelerator integrates with
a standard soft CPU and software ecosystem. The current study asks how a small,
fully inspectable custom datapath and ISA change affects a known FPGA CPU. Moving
platforms would add toolchain, ABI, memory-map and integration work and would
change the architectural research question, not merely improve fairness.

### Recommended reporting discipline

Report three tiers where available:

1. scalar custom CPU: 1,464 cycles;
2. inherited MAC8/custom CPU control: 134 cycles on the common 128-product test;
3. inherited DOT4ACC/custom CPU: 232 cycles for Conv2 and 43 cycles for the
   common 128-product test.

Do not extrapolate these numbers to MicroBlaze or PicoRV32 without an actual
common implementation. If a future external reference is needed, use static
instruction/cycle analysis first and clearly label it as analytical.

## H. Experimental-platform risks

| Risk | Effect | Mitigation |
|---|---|---|
| Scalar ISA is weak | Inflated custom-instruction speed-up | Report MAC8 and scalar controls; state missing MUL/shift/byte ops |
| Fixed 256-word memories | Limits CNN program size and unrolled kernels | Use tiled workloads and report capacity explicitly |
| No cache/DMA/external memory | Limits system-level claims | Keep claims to on-chip deterministic experiments |
| 93 MHz boundary | Timing may become the next bottleneck | Report validated frequency, not theoretical Fmax; preserve post-route evidence |
| Counters overlap | Cannot assign every cycle causally | Use instruction mix and zero-wait facts; call residual cycles unresolved |
| Mature-core figures differ in device/tool | Misleading area/Fmax ranking | Treat published values as context, not direct comparison |
| PicoRV32 archived | Less future maintenance | Pin a commit and use it only as a stable open reference |
| MicroBlaze RTL opacity | Hard to reproduce internal custom opcode changes | Compare attached accelerator/integration capability, not internal RTL edits |

## I. Final platform recommendation

Continue using the custom CPU as the implementation platform and use an
established processor as an external reference. A dual-platform implementation
is not justified for the current Year III scope unless the research question is
explicitly changed to software-portable accelerator integration.

This recommendation is based on:

* architecture: enough pipeline, hazard, memory and branch structure to support
  meaningful microarchitecture experiments;
* reproducibility: pinned RTL, Vivado scripts, self-checking XSim tests,
  waveforms, counters and golden CNN outputs;
* modifiability: direct opcode/datapath access is the main research asset;
* FPGA suitability: measured 2,008 LUT/1,812 FF/5 DSP/2 RAMB18 at 93 MHz;
* risk: changing platform now would add toolchain and integration risk without
  answering the current bottleneck question;
* fairness: the weakness of the scalar baseline is acknowledged and bounded by
  MAC8/DOT4ACC controls and by not claiming external speed-up.

The next bottleneck identified by existing evidence is not memory latency:
Conv2 has zero memory-wait cycles. It is scalar instruction/control and address
overhead, with 280 cycles remaining unclassified. Variant A should therefore be
evaluated as a new work item against the frozen scalar and accelerated controls,
and must measure launch, packing, memory delivery, control and completion cost.

## J. Suggested report wording

“The custom processor was retained as the Year III implementation platform
because its complete RTL, instruction encoding, pipeline control and FPGA
resource path are directly inspectable and reproducible. It is not presented as
a replacement for mature soft processors. AMD MicroBlaze V and the open-source
PicoRV32 core were selected as external references because they provide richer
standard scalar capabilities and established integration mechanisms. The
custom scalar baseline is weaker than these references in general integer
multiply and memory-system features; consequently, the 6.31x result is reported
only as speed-up over the frozen custom scalar program. A same-CPU 128-product
control reports 3.116x from MAC8 to DOT4ACC, and the DOT4ACC result is also
reported as an already accelerated baseline. This preserves the research value
of direct RTL experimentation without claiming an apples-to-apples advantage
over mature soft processors.”

## K. Inherited and new work

### Inherited / pre-Year-III work

* baseline custom CPU and 32-bit custom ISA;
* MAC8 instruction and datapath;
* four-lane DOT4ACC instruction and datapath;
* existing pipeline, forwarding, hazard, branch, BRAM and memory-feed
  optimisations;
* existing retirement, branch, stall, memory-wait and fetch-wait counters;
* inherited 1,464-cycle scalar Conv2 and 232-cycle DOT4ACC characterization;
* inherited FPGA implementation and 93 MHz timing evidence.

### New Year III work

* comparison and justification of the processor platform;
* explicit characterization of scalar versus already accelerated baselines;
* identification of scalar instruction/control overhead as the next bottleneck,
  while marking residual cycles unresolved;
* selection, implementation and evaluation of new Variant A;
* fair reporting of speed-up against both scalar custom CPU and inherited
  DOT4ACC/MAC8 controls.

## L. Jira-ready conclusion

**Conclusion:** Keep `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2` as the
Year III implementation platform and cite MicroBlaze V plus PicoRV32 as external
references. The platform is defensible because it is fully inspectable,
reproducible, FPGA-validated and already supports meaningful MAC8/DOT4ACC
experiments. The principal fairness limitation is that its scalar ISA has no
general multiply, shift or byte extraction, so the 6.31x Conv2 result can be
inflated relative to a mature soft CPU. Mitigate this by reporting the 1,464 to
232 cycle result only as custom-scalar speed-up, also reporting the 134 to 43
cycle MAC8-to-DOT4ACC control, and not claiming external processor speed-up
without a common implementation. Next task: implement and evaluate Variant A
against the frozen scalar and accelerated baselines.

## Exact evidence and sources used

### Repository evidence

* `rtl/cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
* `rtl/register_file.sv`, `rtl/bram_instr_mem.sv`, `rtl/bram_data_mem.sv`
* `rtl/cpu_defs_pkg.sv`, `docs/isa.md`
* `reports/final_cpu_architecture.md`
* `reports/baseline_cnn_workload_profile/baseline_cnn_workload_profile.md`
* `reports/dot4acc_conv2_profile/DOT4ACC_Conv2_profile.md`
* `reports/dot4acc_stage_l_final_comparison.md`
* `reports/kan55_baseline_fpga_implementation/run_result.csv`
* `reports/kan56_timing_baseline/timing_summary.json`
* `tb/tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv`
* `tb/tb_dot4acc_stage_j_ai_workload.sv` and related golden/program files

### Primary external sources

* [AMD MicroBlaze V Processor Reference Guide UG1629](https://docs.amd.com/r/en-US/ug1629-microblaze-v-user-guide)
* [AMD MicroBlaze V pipeline architecture](https://docs.amd.com/r/en-US/ug1629-microblaze-v-user-guide/Pipeline-Architecture)
* [AMD MicroBlaze V 3-stage pipeline](https://docs.amd.com/r/en-US/ug1629-microblaze-v-user-guide/3-Stage-Pipeline)
* [AMD MicroBlaze V 5-stage pipeline](https://docs.amd.com/r/en-US/ug1629-microblaze-v-user-guide/5-Stage-Pipeline)
* [AMD MicroBlaze V memory architecture](https://docs.amd.com/r/2024.1-English/ug1629-microblaze-v-user-guide/Memory-Architecture)
* [AMD MicroBlaze V custom instructions](https://docs.amd.com/r/2024.1-English/ug1629-microblaze-v-user-guide/Custom-Instructions)
* [AMD MicroBlaze V resource utilization](https://docs.amd.com/r/en-US/ug1629-microblaze-v-user-guide/Resource-Utilization)
* [AMD MicroBlaze V HPM event counters](https://docs.amd.com/r/en-US/ug1629-microblaze-v-user-guide/Machine-HPM-Event-Register-mhpmevent)
* [YosysHQ PicoRV32 repository and README](https://github.com/YosysHQ/picorv32)
* [PicoRV32 RTL parameters and interfaces](https://github.com/YosysHQ/picorv32/blob/main/picorv32.v)

