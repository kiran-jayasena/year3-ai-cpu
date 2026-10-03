"""Shared deterministic setup, MNIST loading, hashing, and model statistics."""

from __future__ import annotations

import gzip
import hashlib
import json
import os
import random
import struct
import sys
import urllib.request
from pathlib import Path
from typing import Any

import numpy as np
import torch
from torch.utils.data import Dataset

from model import ARCHITECTURE, SmallCnn


RANDOM_SEED = 349
DATASET_NAME = "MNIST"
PREPROCESSING = "Convert uint8 pixels to FP32 and divide by 255.0; no resize or normalization."
GOLDEN_INDICES = [3, 2, 1, 30, 4, 8, 11, 0, 61, 7]

MNIST_FILES = {
    "train-images-idx3-ubyte.gz": "f68b3c2dcbeaaa9fbdd348bbdeb94873",
    "train-labels-idx1-ubyte.gz": "d53e105ee54ea40749a09fcbcd1e9432",
    "t10k-images-idx3-ubyte.gz": "9fb629c4189551a2d022fa330f9573f3",
    "t10k-labels-idx1-ubyte.gz": "ec29112dd5afa0611ce80d1b7f02629c",
}
MNIST_BASE_URL = "https://ossci-datasets.s3.amazonaws.com/mnist"


def configure_determinism(seed: int = RANDOM_SEED) -> None:
    os.environ["PYTHONHASHSEED"] = str(seed)
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.use_deterministic_algorithms(True)
    torch.backends.mkldnn.enabled = False
    torch.set_num_threads(1)
    try:
        torch.set_num_interop_threads(1)
    except RuntimeError:
        # PyTorch permits setting this only before inter-op work starts.
        pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def md5_file(path: Path) -> str:
    digest = hashlib.md5()  # nosec B324 - canonical MNIST integrity identifiers
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def environment_record() -> dict[str, Any]:
    return {
        "python": sys.version.split()[0],
        "pytorch": str(torch.__version__),
        "numpy": np.__version__,
        "platform": sys.platform,
        "device": "cpu",
        "random_seed": RANDOM_SEED,
        "deterministic_algorithms": True,
        "mkldnn_enabled": False,
        "torch_num_threads": torch.get_num_threads(),
        "dataset": DATASET_NAME,
        "preprocessing": PREPROCESSING,
    }


def ensure_mnist(data_dir: Path) -> Path:
    raw_dir = data_dir / "MNIST" / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    for filename, expected_md5 in MNIST_FILES.items():
        destination = raw_dir / filename
        if destination.exists() and md5_file(destination) == expected_md5:
            continue
        if destination.exists():
            destination.unlink()
        url = f"{MNIST_BASE_URL}/{filename}"
        print(f"Downloading {url}")
        urllib.request.urlretrieve(url, destination)
        actual_md5 = md5_file(destination)
        if actual_md5 != expected_md5:
            destination.unlink(missing_ok=True)
            raise RuntimeError(
                f"MNIST integrity failure for {filename}: {actual_md5} != {expected_md5}"
            )
    return raw_dir


def _read_idx_images(path: Path) -> np.ndarray:
    with gzip.open(path, "rb") as handle:
        magic, count, rows, columns = struct.unpack(">IIII", handle.read(16))
        if magic != 2051 or rows != 28 or columns != 28:
            raise ValueError(f"Unexpected MNIST image header in {path}")
        values = np.frombuffer(handle.read(), dtype=np.uint8)
    return values.reshape(count, rows, columns).copy()


def _read_idx_labels(path: Path) -> np.ndarray:
    with gzip.open(path, "rb") as handle:
        magic, count = struct.unpack(">II", handle.read(8))
        if magic != 2049:
            raise ValueError(f"Unexpected MNIST label header in {path}")
        values = np.frombuffer(handle.read(), dtype=np.uint8)
    if values.size != count:
        raise ValueError(f"Unexpected MNIST label count in {path}")
    return values.copy()


class MnistDataset(Dataset[tuple[torch.Tensor, int]]):
    def __init__(self, data_dir: Path, train: bool) -> None:
        raw_dir = ensure_mnist(data_dir)
        prefix = "train" if train else "t10k"
        self.images = _read_idx_images(raw_dir / f"{prefix}-images-idx3-ubyte.gz")
        self.labels = _read_idx_labels(raw_dir / f"{prefix}-labels-idx1-ubyte.gz")
        if len(self.images) != len(self.labels):
            raise ValueError("MNIST image and label counts differ")

    def __len__(self) -> int:
        return len(self.labels)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, int]:
        image = torch.from_numpy(self.images[index]).to(dtype=torch.float32)
        image = image.unsqueeze(0).div_(255.0)
        return image, int(self.labels[index])


def model_statistics(model: SmallCnn) -> dict[str, Any]:
    parameter_count = sum(parameter.numel() for parameter in model.parameters())
    shapes = {
        "input": [1, 28, 28],
        "conv1": [4, 26, 26],
        "relu1": [4, 26, 26],
        "pool1": [4, 13, 13],
        "conv2": [8, 11, 11],
        "relu2": [8, 11, 11],
        "pool2": [8, 5, 5],
        "flatten": [200],
        "logits": [10],
    }
    activation_elements = {name: int(np.prod(shape)) for name, shape in shapes.items()}
    largest_name = max(activation_elements, key=activation_elements.get)
    macs = {
        "conv1": 4 * 26 * 26 * 1 * 3 * 3,
        "conv2": 8 * 11 * 11 * 4 * 3 * 3,
        "fully_connected": 10 * 200,
    }
    return {
        "architecture": ARCHITECTURE,
        "total_parameters": parameter_count,
        "parameter_storage_fp32_bytes": parameter_count * 4,
        "parameter_storage_int8_estimate_bytes": parameter_count,
        "intermediate_shapes_excluding_batch": shapes,
        "largest_intermediate": {
            "stage": largest_name,
            "elements": activation_elements[largest_name],
            "fp32_bytes": activation_elements[largest_name] * 4,
        },
        "macs_per_inference": {
            "by_layer": macs,
            "total": sum(macs.values()),
            "method": (
                "Conv MACs = output_channels * output_height * output_width * "
                "input_channels * kernel_height * kernel_width; FC MACs = inputs * outputs. "
                "Bias additions, ReLU, comparisons, and pooling are not counted as MACs."
            ),
        },
    }


def print_model_statistics(stats: dict[str, Any]) -> None:
    print(f"Parameters: {stats['total_parameters']:,}")
    print(f"FP32 parameter storage: {stats['parameter_storage_fp32_bytes']:,} bytes")
    print(f"INT8 parameter estimate: {stats['parameter_storage_int8_estimate_bytes']:,} bytes")
    print(f"MACs per inference: {stats['macs_per_inference']['total']:,}")
    largest = stats["largest_intermediate"]
    print(
        f"Largest activation: {largest['stage']} = {largest['elements']:,} values "
        f"({largest['fp32_bytes']:,} FP32 bytes)"
    )
    print("Intermediate shapes (batch dimension excluded):")
    for name, shape in stats["intermediate_shapes_excluding_batch"].items():
        print(f"  {name:8s} {shape}")
