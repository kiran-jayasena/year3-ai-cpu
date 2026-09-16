# Prior Work Boundary

## Immutable baseline

The Year 3 Project starts from the completed summer FPGA CPU engineering
project. Its immutable reference is:

- Git tag: `summer-project-final`
- Commit: `2731a7820988863829c7074acd474ea06902e8f2` (`2731a78`)
- Year 3 baseline tag: `fyp-baseline`

The following capabilities and results existed before the assessed FYP:

- the custom SystemVerilog CPU and scalar instruction set;
- the MAC8 and DOT4ACC instructions;
- pipelined DOT execution;
- forwarding and hazard logic;
- the Stage H memory-feed optimisation;
- the H1.3b functional architecture and H1.3b-T2 physical implementation;
- the repeatably validated 93 MHz result (PASS 5/5);
- the existing Stage J benchmarks; and
- the existing Stage L MAC8/DOT comparison.

These items and their results are **PRIOR WORK**. They must not be presented as
new assessed Year 3 Project contributions. They provide the experimental
baseline against which new work is evaluated.

## Assessed FYP contribution boundary

The assessed contribution begins after `fyp-baseline` and consists of:

- new architectural investigation;
- new experiments;
- expanded verification where required;
- new power and energy evaluation;
- performance/resource/energy trade-off analysis; and
- any new architecture developed after `fyp-baseline`.

Every reported contribution must identify the implementing commit and must make
clear whether a measurement is inherited baseline evidence, a reproduced
baseline measurement, or a new FYP result.
