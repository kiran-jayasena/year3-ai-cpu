"""Reload the frozen model and generate golden tensors without retraining."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path
from typing import Any

import numpy as np
import torch

from model import SmallCnn
from reference_common import (
    DATASET_NAME,
    GOLDEN_INDICES,
    MNIST_FILES,
    PREPROCESSING,
    RANDOM_SEED,
    MnistDataset,
    configure_determinism,
    environment_record,
    model_statistics,
    print_model_statistics,
    sha256_file,
    write_json,
)


ROOT = Path(__file__).resolve().parent
STAGE_NAMES = ["input", "conv1", "relu1", "pool1", "conv2", "relu2", "pool2", "flatten", "logits"]
PARAMETER_NAMES = ["conv1.weight", "conv1.bias", "conv2.weight", "conv2.bias", "fc.weight", "fc.bias"]


def _save_array(path: Path, array: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    np.save(path, np.ascontiguousarray(array), allow_pickle=False)


def _directory_manifest(root: Path, excluded_names: set[str] | None = None) -> dict[str, Any]:
    excluded_names = excluded_names or set()
    files = []
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        if path.name in excluded_names:
            continue
        files.append(
            {
                "path": path.relative_to(root).as_posix(),
                "bytes": path.stat().st_size,
                "sha256": sha256_file(path),
            }
        )
    return {"algorithm": "SHA-256", "file_count": len(files), "files": files}


def _replace_directory(staged: Path, destination: Path) -> None:
    if destination.exists():
        shutil.rmtree(destination)
    staged.replace(destination)


def _export_parameters(model: SmallCnn, export_dir: Path, checkpoint_hash: str) -> None:
    parameter_dir = export_dir / "parameters"
    c_source_dir = export_dir / "c_arrays_source"
    manifest: dict[str, Any] = {
        "checkpoint_sha256": checkpoint_hash,
        "storage_order": "C row-major",
        "binary_format": "raw little-endian IEEE-754 float32, no header",
        "parameters": [],
    }
    state = model.state_dict()
    for name in PARAMETER_NAMES:
        array = state[name].detach().cpu().numpy().astype("<f4", copy=False)
        basename = name.replace(".", "_")
        npy_path = parameter_dir / f"{basename}.npy"
        binary_path = c_source_dir / f"{basename}.f32le"
        _save_array(npy_path, array)
        binary_path.parent.mkdir(parents=True, exist_ok=True)
        binary_path.write_bytes(np.ascontiguousarray(array).tobytes(order="C"))
        manifest["parameters"].append(
            {
                "state_dict_name": name,
                "shape": list(array.shape),
                "dtype": "float32",
                "npy": npy_path.relative_to(export_dir).as_posix(),
                "c_array_source": binary_path.relative_to(export_dir).as_posix(),
                "elements": int(array.size),
            }
        )
    write_json(export_dir / "parameters_manifest.json", manifest)
    (c_source_dir / "README.md").write_text(
        "# C array conversion source\n\n"
        "Each `.f32le` file is a headerless, C-row-major stream of little-endian "
        "IEEE-754 FP32 values. Shapes and names are in `../parameters_manifest.json`. "
        "These files are inputs for the later C-array conversion task; no processor C "
        "implementation is included here.\n",
        encoding="utf-8",
    )


def generate_all(
    output_root: Path,
    checkpoint: Path = ROOT / "artifacts" / "small_cnn_reference.pt",
    data_dir: Path = ROOT / "data",
) -> dict[str, Any]:
    configure_determinism()
    checkpoint = checkpoint.resolve()
    if not checkpoint.exists():
        raise FileNotFoundError(f"Missing checkpoint {checkpoint}; run train_reference.py once")
    checkpoint_hash = sha256_file(checkpoint)
    payload = torch.load(checkpoint, map_location="cpu", weights_only=True)
    if payload["random_seed"] != RANDOM_SEED or payload["dataset"] != DATASET_NAME:
        raise ValueError("Checkpoint metadata does not match this reference definition")
    if list(payload["golden_indices"]) != GOLDEN_INDICES:
        raise ValueError("Checkpoint golden indices do not match this reference definition")

    model = SmallCnn()
    model.load_state_dict(payload["state_dict"], strict=True)
    model.eval()
    test_set = MnistDataset(data_dir, train=False)
    actual_labels = [int(test_set.labels[index]) for index in GOLDEN_INDICES]
    if sorted(actual_labels) != list(range(10)):
        raise ValueError(f"Golden indices no longer select one of every class: {actual_labels}")

    output_root.mkdir(parents=True, exist_ok=True)
    temporary_parent = output_root / ".generation_tmp"
    if temporary_parent.exists():
        shutil.rmtree(temporary_parent)
    temporary_parent.mkdir(parents=True)
    staged_golden = temporary_parent / "golden"
    staged_exports = temporary_parent / "exports"
    predictions: list[dict[str, int]] = []

    try:
        with torch.inference_mode():
            for sample_number, dataset_index in enumerate(GOLDEN_INDICES):
                input_tensor, label = test_set[dataset_index]
                stages = model.forward_stages(input_tensor.unsqueeze(0))
                predicted = int(stages["logits"].argmax(dim=1).item())
                sample_dir = staged_golden / f"sample_{sample_number:03d}"
                _save_array(sample_dir / "raw_input_uint8.npy", test_set.images[dataset_index])
                for stage_name in STAGE_NAMES:
                    array = stages[stage_name].squeeze(0).detach().cpu().numpy().astype(np.float32)
                    _save_array(sample_dir / f"{stage_name}.npy", array)
                _save_array(sample_dir / "ground_truth_label.npy", np.array(label, dtype=np.int64))
                _save_array(sample_dir / "predicted_class.npy", np.array(predicted, dtype=np.int64))
                metadata = {
                    "sample_number": sample_number,
                    "dataset": DATASET_NAME,
                    "dataset_split": "test",
                    "dataset_index": dataset_index,
                    "ground_truth_label": label,
                    "predicted_class": predicted,
                    "prediction_correct": predicted == label,
                    "preprocessing": PREPROCESSING,
                    "checkpoint_sha256": checkpoint_hash,
                    "tensors": {
                        "raw_input_uint8": {"shape": [28, 28], "dtype": "uint8"},
                        **{
                            name: {
                                "shape": list(stages[name].squeeze(0).shape),
                                "dtype": "float32",
                            }
                            for name in STAGE_NAMES
                        },
                    },
                }
                write_json(sample_dir / "metadata.json", metadata)
                predictions.append(
                    {
                        "sample_number": sample_number,
                        "dataset_index": dataset_index,
                        "ground_truth_label": label,
                        "predicted_class": predicted,
                    }
                )

        _export_parameters(model, staged_exports, checkpoint_hash)
        golden_manifest = _directory_manifest(staged_golden, {"sha256_manifest.json"})
        golden_manifest.update(
            {
                "checkpoint_sha256": checkpoint_hash,
                "dataset": DATASET_NAME,
                "dataset_source_files_md5": MNIST_FILES,
                "selected_indices": GOLDEN_INDICES,
            }
        )
        write_json(staged_golden / "sha256_manifest.json", golden_manifest)
        export_manifest = _directory_manifest(staged_exports, {"sha256_manifest.json"})
        export_manifest["checkpoint_sha256"] = checkpoint_hash
        write_json(staged_exports / "sha256_manifest.json", export_manifest)

        _replace_directory(staged_golden, output_root / "golden")
        _replace_directory(staged_exports, output_root / "exports")
    finally:
        shutil.rmtree(temporary_parent, ignore_errors=True)

    stats = model_statistics(model)
    generation_summary = {
        "checkpoint": checkpoint.name,
        "checkpoint_sha256": checkpoint_hash,
        "environment": environment_record(),
        "model_statistics": stats,
        "samples": predictions,
        "test_accuracy_from_training": payload["training"]["final_test_accuracy"],
    }
    write_json(output_root / "results" / "golden_generation.json", generation_summary)
    print_model_statistics(stats)
    for item in predictions:
        print(
            f"sample_{item['sample_number']:03d}: index={item['dataset_index']}, "
            f"label={item['ground_truth_label']}, predicted={item['predicted_class']}"
        )
    print(f"Checkpoint SHA-256: {checkpoint_hash}")
    return generation_summary


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-root", type=Path, default=ROOT)
    parser.add_argument(
        "--checkpoint", type=Path, default=ROOT / "artifacts" / "small_cnn_reference.pt"
    )
    parser.add_argument("--data-dir", type=Path, default=ROOT / "data")
    return parser.parse_args()


if __name__ == "__main__":
    arguments = parse_args()
    generate_all(arguments.output_root.resolve(), arguments.checkpoint, arguments.data_dir)
