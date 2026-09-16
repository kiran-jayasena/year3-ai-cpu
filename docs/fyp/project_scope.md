# Project Scope

## Title

**Design and Evaluation of a Resource-Efficient Single-Core CPU Optimised for
AI Applications**

## Main research question

Which architectural modifications provide the best improvement in AI workload
performance for the FPGA resources and energy they consume on a
resource-constrained single-core CPU?

## Motivation

The objective is not simply to prove that AI workloads can run on a
single-core processor. The project investigates whether carefully chosen
architectural modifications can provide useful AI performance without a
disproportionate hardware-resource or energy cost.

Low-cost and energy-efficient local AI processing could be valuable in IoT and
other resource-constrained environments, including applications where power,
network connectivity and computing infrastructure are limited. This is a
motivation and research hypothesis, not a result that the project claims to
have established already.

## Scope boundary

The completed summer CPU is the experimental baseline. New assessed work must
be implemented after `fyp-baseline`, evaluated by controlled experiments, and
compared with the frozen baseline using correctness, performance, timing,
resource, power and energy evidence.

This setup commit introduces no new CPU architecture or AI accelerator.
