"""Train and freeze the small FP32 MNIST reference model exactly once."""

from __future__ import annotations

import argparse
from pathlib import Path

import torch
from torch import nn
from torch.utils.data import DataLoader

from model import ARCHITECTURE, SmallCnn
from reference_common import (
    DATASET_NAME,
    GOLDEN_INDICES,
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


def evaluate(model: SmallCnn, loader: DataLoader) -> tuple[float, float]:
    model.eval()
    loss_function = nn.CrossEntropyLoss(reduction="sum")
    total_loss = 0.0
    correct = 0
    total = 0
    with torch.inference_mode():
        for inputs, labels in loader:
            logits = model(inputs)
            total_loss += float(loss_function(logits, labels).item())
            correct += int((logits.argmax(dim=1) == labels).sum().item())
            total += labels.numel()
    return total_loss / total, correct / total


def train(args: argparse.Namespace) -> None:
    configure_determinism()
    checkpoint = args.checkpoint.resolve()
    if checkpoint.exists() and not args.overwrite:
        raise FileExistsError(
            f"Frozen checkpoint already exists: {checkpoint}. "
            "Refusing to retrain silently; pass --overwrite only for an intentional replacement."
        )

    train_set = MnistDataset(args.data_dir, train=True)
    test_set = MnistDataset(args.data_dir, train=False)
    generator = torch.Generator().manual_seed(RANDOM_SEED)
    train_loader = DataLoader(
        train_set,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=0,
        generator=generator,
    )
    test_loader = DataLoader(test_set, batch_size=256, shuffle=False, num_workers=0)

    model = SmallCnn()
    optimizer = torch.optim.Adam(model.parameters(), lr=args.learning_rate)
    loss_function = nn.CrossEntropyLoss()
    history: list[dict[str, float | int]] = []

    for epoch in range(1, args.epochs + 1):
        model.train()
        running_loss = 0.0
        examples = 0
        for inputs, labels in train_loader:
            optimizer.zero_grad(set_to_none=True)
            logits = model(inputs)
            loss = loss_function(logits, labels)
            loss.backward()
            optimizer.step()
            running_loss += float(loss.item()) * labels.numel()
            examples += labels.numel()
        test_loss, test_accuracy = evaluate(model, test_loader)
        epoch_result = {
            "epoch": epoch,
            "train_loss": running_loss / examples,
            "test_loss": test_loss,
            "test_accuracy": test_accuracy,
        }
        history.append(epoch_result)
        print(
            f"Epoch {epoch}/{args.epochs}: train_loss={epoch_result['train_loss']:.6f}, "
            f"test_loss={test_loss:.6f}, test_accuracy={test_accuracy:.4%}"
        )

    checkpoint.parent.mkdir(parents=True, exist_ok=True)
    checkpoint_payload = {
        "format_version": 1,
        "model_name": "SmallCnn",
        "state_dict": model.state_dict(),
        "architecture": ARCHITECTURE,
        "dataset": DATASET_NAME,
        "preprocessing": PREPROCESSING,
        "random_seed": RANDOM_SEED,
        "golden_indices": GOLDEN_INDICES,
        "training": {
            "epochs": args.epochs,
            "batch_size": args.batch_size,
            "learning_rate": args.learning_rate,
            "optimizer": "Adam",
            "final_test_loss": history[-1]["test_loss"],
            "final_test_accuracy": history[-1]["test_accuracy"],
        },
        "environment": environment_record(),
    }
    torch.save(checkpoint_payload, checkpoint)
    checkpoint_hash = sha256_file(checkpoint)
    checkpoint.with_suffix(checkpoint.suffix + ".sha256").write_text(
        f"{checkpoint_hash}  {checkpoint.name}\n", encoding="ascii"
    )

    stats = model_statistics(model)
    summary = {
        "checkpoint": str(checkpoint.relative_to(ROOT)),
        "checkpoint_sha256": checkpoint_hash,
        "environment": environment_record(),
        "history": history,
        "model_statistics": stats,
        "selected_golden_indices": GOLDEN_INDICES,
    }
    write_json(ROOT / "results" / "training_summary.json", summary)
    print_model_statistics(stats)
    print(f"Frozen checkpoint: {checkpoint}")
    print(f"Checkpoint SHA-256: {checkpoint_hash}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--batch-size", type=int, default=64)
    parser.add_argument("--learning-rate", type=float, default=1.0e-3)
    parser.add_argument("--data-dir", type=Path, default=ROOT / "data")
    parser.add_argument(
        "--checkpoint", type=Path, default=ROOT / "artifacts" / "small_cnn_reference.pt"
    )
    parser.add_argument("--overwrite", action="store_true")
    return parser.parse_args()


if __name__ == "__main__":
    train(parse_args())
