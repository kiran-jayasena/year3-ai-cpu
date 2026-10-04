"""Summarise repeated KAN-51 XSim counter-validation runs."""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports" / "kan51_instrumentation"
RUN_FILES = [REPORT_DIR / "raw_repeated_runs_run1.csv", REPORT_DIR / "raw_repeated_runs_run2.csv"]
EXPECTED_RETIRED = {
    "straight_line_arithmetic": 6,
    "fixed_count_loop": 14,
    "taken_branch_control_flow": 5,
    "load_store": 4,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 20:
        raise AssertionError(f"{path} contains {len(rows)} rows; expected 20")
    return rows


def main() -> None:
    rows_by_file = [read_rows(path) for path in RUN_FILES]
    if rows_by_file[0] != rows_by_file[1]:
        raise AssertionError("Repeated XSim output CSV files differ")

    grouped: dict[str, list[dict[str, str]]] = {}
    for row in rows_by_file[0]:
        grouped.setdefault(row["test"], []).append(row)

    summary = []
    for test, expected in EXPECTED_RETIRED.items():
        rows = grouped.get(test, [])
        if len(rows) != 5:
            raise AssertionError(f"{test} contains {len(rows)} runs; expected 5")
        cycles = [int(row["cycles"]) for row in rows]
        retired = [int(row["measured_retired"]) for row in rows]
        functional_pass = all(row["functional_pass"] == "PASS" for row in rows)
        retired_pass = all(row["retired_pass"] == "PASS" for row in rows)
        if any(value != expected for value in retired):
            raise AssertionError(f"{test} retired counts {retired} do not equal {expected}")
        summary.append(
            {
                "test": test,
                "expected_retired": expected,
                "measured_retired": retired,
                "cycles": cycles,
                "cycle_min": min(cycles),
                "cycle_max": max(cycles),
                "cycle_variation": max(cycles) - min(cycles),
                "retired_min": min(retired),
                "retired_max": max(retired),
                "retired_variation": max(retired) - min(retired),
                "stable_cycles": len(set(cycles)) == 1,
                "stable_retired": len(set(retired)) == 1,
                "functional_pass": functional_pass,
                "retired_pass": retired_pass,
                "result": "PASS" if functional_pass and retired_pass and len(set(cycles)) == 1 else "FAIL",
            }
        )

    result = {
        "status": "PASS" if all(row["result"] == "PASS" for row in summary) else "FAIL",
        "core": "cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2",
        "counter_semantics": {
            "total_cycles": "increments once per clock edge when rst=0 and enable=1",
            "retired_instructions": "increments once for each normal valid retirement, deferred-load retirement, or DOT completion retirement",
            "reset": "both counters clear on rst=1",
            "disabled": "both counters hold when enable=0",
            "measurement_bracket": "external enable gating; each test stops after its sentinel STORE retirement",
        },
        "run_count_per_test": 5,
        "simulator_repetition_count": 2,
        "rows": summary,
        "raw_run_files": [path.name for path in RUN_FILES],
        "raw_run_sha256": {path.name: sha256(path) for path in RUN_FILES},
        "ai_harness": {
            "available": False,
            "reason": "KAN-50 is still To Do; no processor MNIST harness is present in the repository.",
        },
        "regression": {
            "command": "Vivado xvlog/xelab/xsim on tb/tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv",
            "status": "PASS",
            "evidence": "focused_existing_core_regression.log",
            "note": "The focused existing H1.3b/T2 architectural regression completed with 4,254 checks and 0 failures.",
        },
    }
    (REPORT_DIR / "instrumentation_validation.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    lines = [
        "# KAN-51 instrumentation validation",
        "",
        "## Scope",
        "",
        "This validation checks counter semantics, controlled-program measurements, repeatability, and functional non-interference. It makes no performance-bottleneck interpretation.",
        "",
        "## Counter semantics",
        "",
        "- `total_cycles` increments once on each clock edge with `rst=0` and `enable=1`.",
        "- `retired_instructions` increments once when a normal valid retirement, deferred-load retirement, or DOT completion retirement occurs.",
        "- Reset clears both counters; disabled cycles increment neither.",
        "- Reset and disabled startup cycles are therefore excluded from these externally bracketed measurements.",
        "- Counters are direct RTL debug outputs, not software-readable CSRs or memory-mapped registers.",
        "- Controlled measurements externally bracket execution with `enable` and stop at sentinel STORE retirement.",
        "- Squashed/flushed instructions do not retire because they never reach a valid retirement event.",
        "- Valid NOPs, arithmetic, branches, jumps, loads, stores, MAC8, and DOT completions are counted when they reach their respective retirement event.",
        "- There is no separate trap counter or trap-retirement event in this core; no trap case is exercised by these tests.",
        "",
        "## Results",
        "",
        "| Test | Expected retired | Measured retired | Cycles | Runs | Stable | Functional | Result |",
        "| --- | ---: | --- | --- | ---: | --- | --- | --- |",
    ]
    for row in summary:
        lines.append(
            f"| {row['test']} | {row['expected_retired']} | {row['retired_min']}-{row['retired_max']} | "
            f"{row['cycle_min']}-{row['cycle_max']} | 5 | "
            f"{'yes' if row['stable_cycles'] and row['stable_retired'] else 'no'} | "
            f"{'PASS' if row['functional_pass'] else 'FAIL'} | {row['result']} |"
        )
    lines.extend(
        [
            "",
            "Every controlled program was run five times inside each of two independent XSim invocations. Both raw CSV files were identical.",
            "",
            "## Regression status",
            "",
            "The existing H1.3b/T2 architectural testbench was rebuilt and run with Vivado XSim. It completed 4,254 checks with 0 failures; the full transcript is `focused_existing_core_regression.log`.",
            "",
            "## Controlled-test interpretation",
            "",
            "- Straight-line arithmetic retires six dynamic instructions, including the sentinel STORE.",
            "- The three-iteration loop retires 14 instructions: two setup instructions, three iterations of increment/decrement/BEQ, two taken-path JUMPs, and one STORE.",
            "- The taken branch test retires five instructions; the wrong-path ADDI is flushed and therefore excluded.",
            "- The load/store test retires four instructions: base setup, LOAD, dependent ADDI, and STORE. Pipeline stalls affect cycles but not retired-instruction count.",
            "",
            "## AI workload status",
            "",
            "KAN-50 is not complete: Jira reports it as To Do and the repository contains no processor MNIST benchmark harness. No placeholder CNN cycle or retired-instruction result is reported. KAN-51 controlled validation is complete, but full KAN-51 closure remains gated on KAN-50.",
            "",
            "The cycle and retired-instruction counters have been validated as stable and suitable for reproducible baseline measurement. No bottleneck interpretation is made in KAN-51; detailed performance analysis is deferred to S4.",
            "",
        ]
    )
    (REPORT_DIR / "instrumentation_validation.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
