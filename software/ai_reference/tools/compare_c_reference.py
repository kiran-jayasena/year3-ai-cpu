"""Build the scalar C reference and compare every stage with KAN-349."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import struct
import subprocess
from pathlib import Path
from typing import Any

import numpy as np


REFERENCE_ROOT = Path(__file__).resolve().parents[1]
C_REFERENCE_DIR = REFERENCE_ROOT / "c_reference"
BUILD_DIR = C_REFERENCE_DIR / "build"
RESULTS_DIR = C_REFERENCE_DIR / "results"
GOLDEN_DIR = REFERENCE_ROOT / "golden"
PARAMETER_DIR = REFERENCE_ROOT / "exports" / "c_arrays_source"
DEFAULT_TOLERANCE = 1.0e-5
BUILD_FLAGS = [
    "-std=c11",
    "-O0",
    "-Wall",
    "-Wextra",
    "-Werror",
    "-pedantic",
    "-ffp-contract=off",
    "-Wl,--no-insert-timestamp",
]

STAGES: dict[str, tuple[int, ...]] = {
    "input": (1, 28, 28),
    "conv1": (4, 26, 26),
    "relu1": (4, 26, 26),
    "pool1": (4, 13, 13),
    "conv2": (8, 11, 11),
    "relu2": (8, 11, 11),
    "pool2": (8, 5, 5),
    "flatten": (200,),
    "logits": (10,),
}

MAC_COUNTS = {"conv1": 24_336, "conv2": 34_848, "fully_connected": 2_000}


def run_command(command: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def find_gcc() -> str:
    compiler = shutil.which("gcc")
    if compiler is None:
        raise RuntimeError("GCC was not found on PATH; install GCC/MinGW or pass it on PATH")
    return compiler


def build_reference(clean: bool) -> tuple[Path, str]:
    if clean and BUILD_DIR.exists():
        shutil.rmtree(BUILD_DIR)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    compiler = find_gcc()
    executable = BUILD_DIR / "cnn_reference.exe"
    command = [
        compiler,
        *BUILD_FLAGS,
        str(C_REFERENCE_DIR / "cnn_reference.c"),
        str(C_REFERENCE_DIR / "parameter_loader.c"),
        str(C_REFERENCE_DIR / "main.c"),
        "-o",
        str(executable),
    ]
    run_command(command)
    compiler_version = run_command([compiler, "--version"]).stdout.splitlines()[0]
    return executable, compiler_version


def load_generated_tensor(path: Path, shape: tuple[int, ...]) -> np.ndarray:
    values = np.fromfile(path, dtype="<f4")
    expected_elements = int(np.prod(shape))
    if values.size != expected_elements:
        raise AssertionError(f"{path} has {values.size} values; expected {expected_elements}")
    return values.reshape(shape)


def compare_sample(executable: Path, sample_number: int, tolerance: float) -> dict[str, Any]:
    sample_name = f"sample_{sample_number:03d}"
    golden_sample = GOLDEN_DIR / sample_name
    raw_input = np.load(golden_sample / "raw_input_uint8.npy", allow_pickle=False)
    if raw_input.dtype != np.uint8 or raw_input.shape != (28, 28) or not raw_input.flags.c_contiguous:
        raise AssertionError(f"Unexpected raw input format for {sample_name}")

    input_dir = BUILD_DIR / "inputs"
    output_dir = BUILD_DIR / "outputs" / sample_name
    input_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    input_path = input_dir / f"{sample_name}.u8"
    raw_input.tofile(input_path)

    process = run_command(
        [str(executable), str(PARAMETER_DIR), str(input_path), str(output_dir)]
    )
    stage_results: dict[str, Any] = {}
    for stage_name, shape in STAGES.items():
        actual = load_generated_tensor(output_dir / f"{stage_name}.f32le", shape)
        expected = np.load(golden_sample / f"{stage_name}.npy", allow_pickle=False)
        if expected.dtype != np.float32 or expected.shape != shape:
            raise AssertionError(f"Unexpected golden format for {sample_name}/{stage_name}")
        difference = np.abs(actual.astype(np.float64) - expected.astype(np.float64))
        max_absolute_error = float(difference.max(initial=0.0))
        stage_results[stage_name] = {
            "max_absolute_error": max_absolute_error,
            "pass": bool(np.isfinite(actual).all() and max_absolute_error <= tolerance),
        }

    prediction_bytes = (output_dir / "predicted_class.i32le").read_bytes()
    if len(prediction_bytes) != 4:
        raise AssertionError(f"Invalid prediction output for {sample_name}")
    actual_prediction = struct.unpack("<i", prediction_bytes)[0]
    expected_prediction = int(
        np.load(golden_sample / "predicted_class.npy", allow_pickle=False).item()
    )
    metadata = json.loads((golden_sample / "metadata.json").read_text(encoding="utf-8"))
    prediction_matches = actual_prediction == expected_prediction

    return {
        "sample": sample_name,
        "dataset_index": metadata["dataset_index"],
        "ground_truth_label": metadata["ground_truth_label"],
        "expected_prediction": expected_prediction,
        "actual_prediction": actual_prediction,
        "prediction_matches": prediction_matches,
        "all_layers_pass": all(result["pass"] for result in stage_results.values()),
        "stages": stage_results,
        "program_output": process.stdout.strip(),
    }


def write_markdown_report(report: dict[str, Any], path: Path) -> None:
    lines = [
        "# KAN-350 C reference comparison results",
        "",
        f"Overall result: **{report['status']}**",
        "",
        f"Absolute FP32 tolerance: `{report['absolute_tolerance']:.1e}`",
        "",
        "## Maximum absolute error across all ten samples",
        "",
        "| Stage | Shape | Maximum absolute error | Result |",
        "| --- | --- | ---: | --- |",
    ]
    for stage_name, shape in STAGES.items():
        stage = report["maximum_absolute_error_by_stage"][stage_name]
        lines.append(
            f"| {stage_name} | {'x'.join(str(value) for value in shape)} | "
            f"{stage['max_absolute_error']:.9g} | {'PASS' if stage['pass'] else 'FAIL'} |"
        )
    lines.extend(
        [
            "",
            "## Per-sample predictions",
            "",
            "| Sample | Dataset index | Ground truth | Expected | C result | Layers | Prediction |",
            "| --- | ---: | ---: | ---: | ---: | --- | --- |",
        ]
    )
    for sample in report["samples"]:
        lines.append(
            f"| {sample['sample']} | {sample['dataset_index']} | {sample['ground_truth_label']} | "
            f"{sample['expected_prediction']} | {sample['actual_prediction']} | "
            f"{'PASS' if sample['all_layers_pass'] else 'FAIL'} | "
            f"{'PASS' if sample['prediction_matches'] else 'FAIL'} |"
        )
    lines.extend(
        [
            "",
            "The comparison used the unmodified KAN-349 golden `.npy` tensors and raw parameter exports.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--clean", action="store_true", help="remove and recreate the build directory")
    parser.add_argument("--tolerance", type=float, default=DEFAULT_TOLERANCE)
    args = parser.parse_args()
    if args.tolerance < 0.0:
        parser.error("--tolerance must be non-negative")

    executable, compiler_version = build_reference(args.clean)
    samples = [compare_sample(executable, number, args.tolerance) for number in range(10)]
    maximum_by_stage: dict[str, Any] = {}
    for stage_name in STAGES:
        maximum = max(sample["stages"][stage_name]["max_absolute_error"] for sample in samples)
        maximum_by_stage[stage_name] = {
            "max_absolute_error": maximum,
            "pass": maximum <= args.tolerance,
        }

    all_pass = all(sample["all_layers_pass"] and sample["prediction_matches"] for sample in samples)
    report = {
        "status": "PASS" if all_pass else "FAIL",
        "absolute_tolerance": args.tolerance,
        "comparison_rule": "finite C output and max(abs(C - KAN-349 golden)) <= tolerance",
        "compiler": compiler_version,
        "build_flags": BUILD_FLAGS,
        "executable_sha256": sha256_file(executable),
        "parameter_source": "../../exports/c_arrays_source/*.f32le",
        "golden_source": "../../golden/sample_000 through sample_009",
        "tensor_layout": "CHW C-row-major; convolution weights OIHW; FC weights [output][input]",
        "mac_counts": {**MAC_COUNTS, "total": sum(MAC_COUNTS.values())},
        "maximum_absolute_error_by_stage": maximum_by_stage,
        "samples": samples,
    }
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    json_path = RESULTS_DIR / "comparison_results.json"
    markdown_path = RESULTS_DIR / "comparison_results.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown_report(report, markdown_path)

    print(f"Compiler: {compiler_version}")
    print(f"Tolerance: {args.tolerance:.1e}")
    print("Stage maxima:")
    for stage_name, result in maximum_by_stage.items():
        print(
            f"  {stage_name:8s} max_abs_error={result['max_absolute_error']:.9g} "
            f"{'PASS' if result['pass'] else 'FAIL'}"
        )
    for sample in samples:
        print(
            f"  {sample['sample']}: layers={'PASS' if sample['all_layers_pass'] else 'FAIL'}, "
            f"prediction={sample['actual_prediction']} "
            f"({'PASS' if sample['prediction_matches'] else 'FAIL'})"
        )
    print(f"Overall: {report['status']}")
    return 0 if all_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
