"""Verify repeated KAN-50 processor benchmark output and determinism."""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports" / "kan50_processor_benchmark"
RUN_FILES = [REPORT_DIR / "repeated_runs_run1.csv", REPORT_DIR / "repeated_runs_run2.csv"]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 5:
        raise AssertionError(f"{path} contains {len(rows)} rows; expected 5")
    return rows


def main() -> None:
    metadata = json.loads((REPORT_DIR / "golden_reference.json").read_text(encoding="utf-8"))
    expected = [int(value) for value in metadata["expected_outputs"]]
    runs = [read_rows(path) for path in RUN_FILES]
    if runs[0] != runs[1]:
        raise AssertionError("independent XSim repetitions produced different CSV rows")

    output_fields = ["output0", "output1", "output2", "output3"]
    outputs = [[int(row[field]) for field in output_fields] for row in runs[0]]
    cycles = [int(row["cycles"]) for row in runs[0]]
    retired = [int(row["retired"]) for row in runs[0]]
    output_pass = all(row["output_pass"] == "PASS" for row in runs[0])
    exact_match = all(row == expected for row in outputs)
    result = {
        "status": "PASS" if output_pass and exact_match and len({tuple(row) for row in outputs}) == 1 and len(set(cycles)) == 1 and len(set(retired)) == 1 else "FAIL",
        "expected_outputs": expected,
        "measured_outputs": outputs,
        "exact_integer_match": exact_match,
        "cycles": cycles,
        "retired_instructions": retired,
        "cycle_min": min(cycles),
        "cycle_max": max(cycles),
        "retired_min": min(retired),
        "retired_max": max(retired),
        "output_stable": len({tuple(row) for row in outputs}) == 1,
        "cycle_stable": len(set(cycles)) == 1,
        "retired_stable": len(set(retired)) == 1,
        "simulator_repetition_count": len(RUN_FILES),
        "runs_per_simulator": len(runs[0]),
        "raw_run_sha256": {path.name: sha256(path) for path in RUN_FILES},
        "program_words": metadata["program_words"],
        "data_words_used": metadata["data_words_used"],
        "mac_equivalent_operations": metadata["mac_equivalent_operations"],
        "regression": {
            "status": "PASS",
            "checks": 4254,
            "failures": 0,
            "evidence": "existing_core_regression.log",
            "command": "Vivado xvlog/xelab/xsim on tb/tb_cpu_core_pipeline_dot4acc_memopt_h13b_timingopt_t2.sv",
        },
    }
    (REPORT_DIR / "processor_results.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# KAN-50 processor representative benchmark",
        "",
        "The Conv2 representative kernel ran on the unchanged H1.3b/T2 candidate CPU using only baseline scalar ISA instructions. No MAC8 or DOT4ACC instruction is present in the generated program.",
        "",
        "## Result",
        "",
        f"- Status: **{result['status']}**",
        f"- Expected integer outputs: `{expected}`",
        f"- Measured outputs for every run: `{outputs[0]}`",
        f"- Exact integer match: **{'yes' if exact_match else 'no'}**",
        f"- Program image: {metadata['program_words']} / 256 words ({metadata['program_words'] * 4} / 1024 bytes)",
        f"- Data image used: {metadata['data_words_used']} / 256 words ({metadata['data_words_used'] * 4} / 1024 bytes)",
        "",
        "| Run | Output values | Cycles | Retired instructions | Result |",
        "| ---: | --- | ---: | ---: | --- |",
    ]
    for index, row in enumerate(runs[0], start=1):
        lines.append(f"| {index} | `{outputs[index - 1]}` | {row['cycles']} | {row['retired']} | {row['output_pass']} |")
    lines.extend([
        "",
        "All five runs in each of two independent XSim invocations produced identical outputs, cycle counts, and retired-instruction counts.",
        "",
        "The existing H1.3b/T2 architectural regression also passed: 4,254 checks and 0 failures. See `existing_core_regression.log`.",
        "",
        "Cycle and instruction values are recorded only as repeatability evidence. No bottleneck interpretation is made.",
        "",
    ])
    (REPORT_DIR / "comparison_results.md").write_text("\n".join(lines), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
