# KAN-56 Methodology

The frozen `fyp-stage3-baseline` implementation flow was run in the isolated workspace `C:\FPGA\kan56-timing-sweep`.

Only the target clock period and corresponding frequency label were varied. The following remained unchanged for every run:

- CPU RTL and FPGA wrapper
- ISA/decode/control and memory architecture
- Basys 3 XDC, except for the flow-generated clock-period override
- synthesis, optimisation, placement, and routing directives (`Default`; physical optimisation `NotRun`)
- Vivado 2026.1 and FPGA part `xc7a35tcpg236-1`
- instruction image and all source files

## Pass/fail criteria

A point is PASS only when synthesis, placement, and routing complete; WNS is non-negative; TNS is zero; and worst hold slack is non-negative. A negative WNS or negative TNS is retained as a setup failure even when routing completes. No negative result was rounded to zero.

The initial points were 10.50, 10.25, 10.00, and 9.75 ns. After the 10.50 ns failure and the known 10.752688172 ns KAN-55 pass, the boundary was narrowed with 10.70 ns. The accepted point was repeated three times.

This timing boundary is a physical implementation result only. It is not an AI-workload bottleneck claim.

