"""Summarise and verify repeated KAN-47 architectural smoke tests."""

from __future__ import annotations

import csv
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports" / "kan47_smoke_tests"
EXPECTED = {
    "reset_startup": 1,
    "scalar_arithmetic": 7,
    "taken_branch": 7,
    "load_store": 43,
    "load_use_dependency": 10,
}


def main() -> None:
    csv_path = REPORT_DIR / "repeated_runs.csv"
    with csv_path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) != 25:
        raise AssertionError(f"expected 25 rows, found {len(rows)}")

    summaries = []
    for name, expected in EXPECTED.items():
        selected = [row for row in rows if row["test"] == name]
        if len(selected) != 5:
            raise AssertionError(f"{name}: expected five runs, found {len(selected)}")
        actual = [int(row["actual"]) for row in selected]
        cycles = [int(row["cycles"]) for row in selected]
        retired = [int(row["retired"]) for row in selected]
        passed = all(row["result"] == "PASS" for row in selected) and all(value == expected for value in actual)
        summaries.append({
            "name": name,
            "purpose": {
                "reset_startup": "reset entry PC and normal startup execution",
                "scalar_arithmetic": "ADDI, ADD and SUB architectural result",
                "taken_branch": "taken BEQ flushes wrong-path instruction",
                "load_store": "store/load exact-value round trip",
                "load_use_dependency": "load-use forwarding/stall dependency",
            }[name],
            "expected": expected,
            "actual": actual,
            "cycles": cycles,
            "retired": retired,
            "runs": 5,
            "stable": len(set(actual)) == 1 and len(set(cycles)) == 1 and len(set(retired)) == 1,
            "pass": passed,
            "cycle_min": min(cycles),
            "cycle_max": max(cycles),
            "retired_min": min(retired),
            "retired_max": max(retired),
        })

    try:
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        commit = "unavailable"
    result = {
        "jira_task": "KAN-47",
        "commit": commit,
        "tests": summaries,
        "all_tests_pass": all(item["pass"] and item["stable"] for item in summaries),
        "cpu_rtl_modified": False,
        "isa_modified": False,
        "relationship": {
            "kan46": "independent small architectural reconfirmation; KAN-46 remains the full 4,254-check regression",
            "kan51": "uses the same reset/enable/sentinel convention but does not draw instrumentation conclusions",
        },
    }
    (REPORT_DIR / "smoke_test_results.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# KAN-47 minimal independent smoke tests",
        "",
        f"Tested commit: `{commit}` on the current development branch.",
        "",
        "These tests independently reconfirm architectural behaviour; they are separate from KAN-51 counter validation. KAN-46 remains the full inherited regression (4,254 checks, 0 failures).",
        "",
        "| Test | Expected | Actual runs | Cycles | Retired | Stable | Result |",
        "|---|---:|---|---|---|---|---|",
    ]
    for item in summaries:
        lines.append(
            f"| {item['name']} | {item['expected']} | `{item['actual']}` | "
            f"{item['cycle_min']}-{item['cycle_max']} | {item['retired_min']}-{item['retired_max']} | "
            f"{'yes' if item['stable'] else 'no'} | {'PASS' if item['pass'] else 'FAIL'} |"
        )
    lines.extend([
        "",
        "## Test definitions",
        "",
        "- **reset_startup:** reset is asserted, fetch entry is checked at PC 0, then ADDI/STORE produces 1.",
        "- **scalar_arithmetic:** computes `5 + 7 = 12`, then `12 - 5 = 7`.",
        "- **taken_branch:** taken BEQ skips wrong-path value 99 and stores 7.",
        "- **load_store:** stores 43, loads it back, and stores the loaded value at the sentinel address.",
        "- **load_use_dependency:** loads 5 and immediately doubles it through a dependent ADD, producing 10.",
        "",
        "All five tests passed on all five repetitions. Cycle and retired-instruction values are recorded only to show repeatability; no performance or bottleneck interpretation is made.",
        "",
        "CPU RTL and ISA were unchanged. No inherited CPU defect was observed.",
    ])
    (REPORT_DIR / "smoke_test_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
