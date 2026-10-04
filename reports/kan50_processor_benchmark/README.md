# KAN-50 processor representative benchmark

This package executes a bounded, processor-compatible representative of the frozen S2 MNIST CNN. It is derived from Conv2 and is not a replacement for the independent KAN-349/KAN-350 references.

The unchanged candidate is `cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2`. The program uses only baseline scalar instructions and does not use MAC8, DOT4ACC, hardware multiplication, or any accelerator.

## Reproduce

From the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_kan50_processor_benchmark.ps1
```

The command regenerates the deterministic program/data/golden files, compiles the Vivado XSim testbench, runs two simulator repetitions with five benchmark runs each, and writes `processor_results.json` and `comparison_results.md`.

## Expected result

The generated golden outputs are recorded in `golden_reference.json` and must match every run exactly. The current benchmark reports five identical runs per simulator invocation with stable cycle and retired-instruction counts. Those counters are recorded only for repeatability; no bottleneck interpretation is made.

