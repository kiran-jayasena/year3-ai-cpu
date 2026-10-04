# KAN-45 clean-clone and rebuild report

## Objective

Prove that the inherited CPU baseline can be checked out and simulated from a completely separate clean clone without using generated files or build artifacts from the main working directory.

## Baseline

- Formal tag: `fyp-baseline`
- Required commit: `2731a7820988863829c7074acd474ea06902e8f2`
- Candidate: H1.3b-T2 (`cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2`)
- Clean clone: `C:\FPGA\kan45-clean-rebuild`

The clone was detached at the required commit. Its initial checkout was clean. The only post-build files in the clone were the locally captured environment record and regression log.

## Procedure

1. Recorded the main repository branch/HEAD/status without changing it.
2. Confirmed `C:\FPGA\kan45-clean-rebuild` did not exist.
3. Cloned from `C:\FPGA\systemverilog-fpga-cpu`.
4. Imported the existing local `fyp-baseline` tag reference into the clone only because the source remote did not publish that tag.
5. Checked out the tag and verified HEAD resolved to `2731a7820988863829c7074acd474ea06902e8f2`.
6. Captured tool versions and target part.
7. Compiled and ran the focused H1.3b-T2 testbench using only source files present in the clean clone.

## Environment

The raw environment record is in `environment.txt`:

- Windows 11 Pro, build 26200
- Windows PowerShell 5.1.26100.9444
- Git 2.55.0.windows.1
- Python 3.14.0
- AMD Vivado 2026.1
- Vivado Simulator/XSim 2026.1
- Digilent Basys 3 / `xc7a35tcpg236-1`

## Build and regression result

The focused H1.3b-T2 test compiled and ran successfully:

- 4,254 checks
- 0 failures
- PASS

The result matches the documented KAN-46/H1.3b-T2 expectation. The raw transcript is retained in `baseline_regression.log`.

No synthesis or implementation was attempted because simulation/regression is the minimum KAN-45 requirement and the physical flow was optional.

## Deviations and hidden dependencies

The fresh clone contained the target commit and `summer-project-final`, but not the `fyp-baseline` tag. That tag is currently a local ref in the main repository. It was fetched into the clean clone only for checkout and was not created, moved, or changed in the main repository.

The documented environment-capture helper `scripts/fyp/capture_environment.ps1` is absent at the historical baseline commit. Its invocation failed without changing source files. Equivalent environment fields were captured manually and the result is retained in `environment.txt`.

No generated `.Xil` directory, Vivado run, compiled library, bitstream, checkpoint, or main-repository artifact was used as an input. No RTL, ISA, constraint, project, KAN-349, KAN-350, KAN-50, or KAN-51 file was modified.

## Reproducibility conclusion

The inherited H1.3b-T2 CPU baseline is reproducible from a separate clean clone at `2731a7820988863829c7074acd474ea06902e8f2`. Its focused XSim regression passes 4,254 checks with zero failures and matches the documented baseline result. The only issues found are documentation/ref availability issues: the formal `fyp-baseline` tag is not published to the clone source remote, and the environment helper was added after the inherited tag. Neither issue affects CPU functional reproducibility.
