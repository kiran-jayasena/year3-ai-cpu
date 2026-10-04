# KAN-44 CPU baseline provenance

## Conclusion

The candidate CPU baseline used by the Year III project was inherited from pre-existing summer-project work. Its architecture, repository provenance, verification status and candidate baseline revision have been documented. The Year III project does not claim the original CPU implementation as new work; its contribution begins with reproducible baseline validation, workload selection and mapping, profiling, bottleneck identification, and subsequent AI acceleration design and evaluation.

## Candidate revision

The best-supported file-level candidate revision is:

- Commit: `b90a3dca8a5fb3017a97d705abda9cbb498f88a3`
- Date: 2026-08-10 14:35:36 +01:00
- Author: Kiran Jayasena
- Message: `exp(fpga): evaluate H1.3b-T2 timing recovery`
- Evidence: this commit adds the H1.3b-T2 CPU RTL, FPGA wrapper, implementation script, focused architectural testbench and benchmark testbench together.

The repository-level inherited snapshot is also represented by:

- `summer-project-final` tag: commit `2731a7820988863829c7074acd474ea06902e8f2`
- `fyp-baseline` annotated tag: tag object `047d90a8275472451e7acddf0a2bba41d10f18ee`, pointing to commit `2731a7820988863829c7074acd474ea06902e8f2`; tag message: `Year 3 Project baseline derived from completed summer project`.

The current branch is `fyp-development` at `c6e8896c7cee27c5deb94dd29b49267f9a9efa7c`. Later Year III commits are present, but the candidate H1.3b-T2 RTL, wrapper and focused testbench are unchanged relative to `b90a3dc`.

This is a provenance boundary, not a claim that every file in the repository was created by the `b90a3dc` commit.

## Inherited architecture

The repository supports the following description of the candidate:

- Five-stage in-order 32-bit custom CPU pipeline.
- Synchronous BRAM-style instruction and data memories, defaulting to 256 32-bit words each.
- Base scalar ISA: NOP, ADD, SUB, AND, OR, XOR, ADDI, LOAD, STORE, BEQ and JUMP.
- Pre-existing MAC8 and DOT4ACC experimental AI extensions are present in this candidate path; they are not claimed as Year III work and were not used by the KAN-50 representative benchmark.
- Forwarding and load-use hazard handling.
- Branch/jump redirect and wrong-path pipeline flushing.
- Architectural retirement tracking, including `total_cycles` and `retired_instructions` outputs.
- Basys 3 target using Artix-7 `xc7a35tcpg236-1`, with the corresponding FPGA wrapper and constraints.

The candidate revision's H1.3b-T2 evidence reports a memory-fed N=128 DOT4ACC workload reduction from 294 to 263 cycles and focused architectural verification of 4,254 checks with zero failures. These are inherited project results, not new Year III performance claims.

## Toolchain and environment evidence

Repository-supported tools and environment:

- Windows PowerShell workflow.
- AMD Vivado 2026.1.
- Vivado XSim as the primary simulator.
- Vivado synthesis/implementation targeting `xc7a35tcpg236-1`.
- Python is used for Year III AI reference tooling; KAN-349 records Python 3.14.0, PyTorch 2.14.1 and NumPy 2.5.3.
- GCC/MinGW is used for the desktop KAN-350 C reference, not as a CPU cross-compiler.

No CPU-targeting C compiler, assembler, linker or runtime is claimed by this provenance record.

## Verification status

Pre-existing evidence includes the H1.3b-T2 focused testbench, Stage H memory-feed benchmark, Vivado implementation scripts, and retained timing/resource reports under `reports/dot4acc_stage_h/`. The repository's historical reports record passing focused architectural suites and a highest repeatably validated 93 MHz H1.3b-T2 implementation result.

Year III revalidation and extension are separate work:

- KAN-45: clean clone/build evidence.
- KAN-46: baseline regression.
- KAN-47: smoke tests.
- KAN-48: frozen candidate baseline.
- KAN-50: processor-compatible representative Conv2 benchmark.
- KAN-51: cycle/retired-instruction instrumentation validation.

## Boundary between inherited work and Year III contribution

The inherited CPU architecture, RTL, ISA, FPGA wrapper, historical benchmark programs, and their original verification/performance evidence are pre-existing summer-project work. Year III work begins with independently reproducing and documenting that baseline, selecting and freezing the MNIST workload, creating the desktop correctness oracle, mapping a processor-compatible representative kernel, validating instrumentation, profiling measured execution, identifying measured bottlenecks, and designing/evaluating any justified AI acceleration.

No KAN-44 change modifies RTL, the ISA, Vivado project files, frozen KAN-349/KAN-350/KAN-50/KAN-51 outputs, or Git history.

