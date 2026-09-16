# Experimental Methodology

## Controlled workflow

Each architectural experiment follows this sequence:

```text
identify bottleneck
    -> state hypothesis
    -> implement one controlled architectural change
    -> RTL lint / compile
    -> SystemVerilog functional verification
    -> golden-reference correctness
    -> benchmark cycles
    -> FPGA synthesis / implementation
    -> static timing analysis
    -> resource utilisation
    -> power estimation
    -> energy/workload calculation
    -> compare against fyp-baseline
    -> accept / reject
```

One controlled architectural variable should change per experiment wherever
practical. Each result must be associated with an experiment ID and Git commit.

## Metrics

### Correctness

- PASS/FAIL
- expected result
- actual result

### Performance

- cycles
- retired instructions
- useful MACs
- MAC/cycle
- MMAC/s
- execution time
- speedup

### Timing

- target MHz
- WNS
- TNS
- hold WNS
- setup failures
- highest repeatably timing-clean frequency

### Resources

- LUT
- FF
- BRAM
- DSP
- BUFG

### Power and energy

- total power
- dynamic power where available
- execution time
- energy/workload
- MAC/J
- performance/DSP
- performance/1000 LUT

## Decision rule

An experiment is accepted only when correctness is preserved and the measured
performance benefit is justified by its timing, resource and energy costs.
Otherwise it is rejected or marked inconclusive with the missing evidence
identified explicitly.
