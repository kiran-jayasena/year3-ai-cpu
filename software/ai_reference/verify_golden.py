"""Regenerate the reference twice and require byte-identical outputs."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any

from generate_golden import ROOT, generate_all
from reference_common import GOLDEN_INDICES, sha256_file, write_json


def tree_hashes(root: Path) -> dict[str, str]:
    return {
        path.relative_to(root).as_posix(): sha256_file(path)
        for path in sorted(item for item in root.rglob("*") if item.is_file())
    }


def aggregate_hash(file_hashes: dict[str, str]) -> str:
    digest = hashlib.sha256()
    for name, file_hash in sorted(file_hashes.items()):
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(file_hash.encode("ascii"))
        digest.update(b"\n")
    return digest.hexdigest()


def generated_hashes(root: Path) -> dict[str, str]:
    """Hash only canonical generator outputs, never the local venv or dataset cache."""
    selected: dict[str, str] = {}
    for directory_name in ("golden", "exports"):
        directory = root / directory_name
        for path in sorted(item for item in directory.rglob("*") if item.is_file()):
            selected[path.relative_to(root).as_posix()] = sha256_file(path)
    summary = root / "results" / "golden_generation.json"
    selected[summary.relative_to(root).as_posix()] = sha256_file(summary)
    return selected


def verify(checkpoint: Path, data_dir: Path, canonical_root: Path) -> dict[str, Any]:
    temporary_root = canonical_root / ".verify_tmp"
    if temporary_root.exists():
        shutil.rmtree(temporary_root)
    temporary_root.mkdir(parents=True)
    try:
        run_a = temporary_root / "run_a"
        run_b = temporary_root / "run_b"
        generate_all(run_a, checkpoint, data_dir)
        generate_all(run_b, checkpoint, data_dir)
        hashes_a = tree_hashes(run_a)
        hashes_b = tree_hashes(run_b)
        if hashes_a != hashes_b:
            differing = sorted(set(hashes_a) | set(hashes_b))
            differing = [name for name in differing if hashes_a.get(name) != hashes_b.get(name)]
            raise AssertionError(f"Repeated generation differed: {differing}")

        canonical_files = generated_hashes(canonical_root)
        run_files = generated_hashes(run_a)
        if canonical_files != run_files:
            raise AssertionError("Canonical generated outputs do not match fresh regeneration")

        result = {
            "status": "PASS",
            "method": "Two fresh checkpoint reloads and generations were compared file-by-file using SHA-256.",
            "byte_identical": True,
            "canonical_matches_regeneration": True,
            "compared_file_count": len(hashes_a),
            "aggregate_sha256": aggregate_hash(hashes_a),
            "selected_indices": GOLDEN_INDICES,
            "checkpoint_sha256": sha256_file(checkpoint),
        }
    finally:
        shutil.rmtree(temporary_root, ignore_errors=True)
    write_json(canonical_root / "results" / "reproducibility.json", result)
    print(json.dumps(result, indent=2, sort_keys=True))
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--checkpoint", type=Path, default=ROOT / "artifacts" / "small_cnn_reference.pt"
    )
    parser.add_argument("--data-dir", type=Path, default=ROOT / "data")
    parser.add_argument("--canonical-root", type=Path, default=ROOT)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    verify(args.checkpoint.resolve(), args.data_dir.resolve(), args.canonical_root.resolve())
