# KAN-63 Limitations and Methodological Boundaries

- The workload is a representative CNN convolution kernel, not full end-to-end MNIST inference.
- The benchmark executes scalar software and does not exercise DOT4ACC/MAC8. DOT4ACC remains physically present in the baseline design and is included in resource/power results.
- Power is a Vivado vectorless/default activity estimate with Medium confidence, not a board-level measurement.
- No workload-derived SAIF or VCD activity was used for the power estimate.
- KAN-62 leaves 280 excess cycles unclassified after measured pipeline-fill and control-flush components.
- No measured memory waits or data-hazard/load-use stalls were observed; absence of measured waits does not prove absence of all implementation effects.
- The results are intended primarily for controlled baseline-versus-Variant-A comparison under the comparison contract in the main report.
- KAN-62 classifications are evidence-backed interpretations of the retained trace, not a claim that timing critical paths or resource counts alone identify the workload bottleneck.
