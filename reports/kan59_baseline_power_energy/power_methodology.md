# KAN-59 Power Methodology

## Design and activity source

The power report was generated from the retained routed checkpoint:

`reports/kan55_baseline_fpga_implementation/checkpoints/baseline_routed.dcp`

The checkpoint corresponds to the immutable `fyp-stage3-baseline` commit `f6b25ca196493858cc2b501a0324c4a794c0dd94`, top `fpga_top_pipeline_dot4acc_memopt_h13b_timingopt_t2`, device `xc7a35tcpg236-1`, and Vivado 2026.1 build 6511674.

No SAIF, VCD, or equivalent switching-activity file exists in the retained validated workload evidence. Therefore Vivado's vectorless/default activity propagation was used. The raw report explicitly records `Simulation Activity File: ---` and reports overall confidence `Medium`.

This is a reproducible Vivado estimated baseline, not a direct board power measurement. The same vectorless methodology should be reused for later variant comparisons unless a documented activity-capture flow is introduced consistently for every variant.

## Energy calculation

KAN-58 measured 1,464 cycles at the KAN-56 validated frequency of 93,000,000 Hz:

`execution_time_s = 1464 / 93000000 = 0.000015741935484 s`

Using the report's rounded total and dynamic powers:

- Total energy = `0.086 W × execution_time_s` = `1.353806 µJ`
- Dynamic energy = `0.014 W × execution_time_s` = `0.220387 µJ`
- Total energy/MAC-equivalent = `1.353806 µJ / 36` = `37.605735 nJ/MAC`
- Dynamic energy/MAC-equivalent = `0.220387 µJ / 36` = `6.121864 nJ/MAC`

The component powers are Vivado report values rounded to the displayed precision; energy values inherit that rounding.

## Fairness note

The complete frozen baseline includes `dot4acc_pipeline_inst` and four DSP48E1 resources. The KAN-58 scalar benchmark does not issue DOT4ACC or MAC8 instructions, so that path is not workload-exercised. It was not removed or disabled for this estimate; the power result covers the complete implemented baseline, including physically present DOT4ACC hardware.

