# KAN-349 results summary

## Outcome

The independent FP32 desktop reference trained successfully, froze a specific
checkpoint, generated inputs and every important intermediate activation for a
fixed ten-sample MNIST test set, exported all model parameters, and passed two
fresh byte-for-byte reproducibility generations.

The KAN-348 Jira issue did not record its intended MNIST/Fashion-MNIST choice.
KAN-349 therefore uses MNIST and records that resolution explicitly.

## Frozen model

- Architecture: Conv1 (1 to 4, 3x3), ReLU, 2x2 max pool; Conv2 (4 to 8,
  3x3), ReLU, 2x2 max pool; flatten 200; fully connected 200 to 10.
- Total parameters: 2,346.
- FP32 parameter storage: 9,384 bytes (9.164 KiB).
- Simple all-INT8 parameter estimate: 2,346 bytes (2.291 KiB).
- Test accuracy after three epochs: 96.47% (9,647 / 10,000).
- Approximate MACs per inference: 61,184 (24,336 Conv1 + 34,848 Conv2 +
  2,000 fully connected).
- Largest activation: Conv1/ReLU1, 2,704 FP32 elements = 10,816 bytes.
- Checkpoint: `../artifacts/small_cnn_reference.pt`.
- Checkpoint SHA-256:
  `9216dc089e92c480214db348c80bd6e1237ac14ff2a665345b228123be47759c`.

## Golden samples

| Sample | MNIST test index | Ground truth | Predicted |
| ---: | ---: | ---: | ---: |
| 000 | 3 | 0 | 0 |
| 001 | 2 | 1 | 1 |
| 002 | 1 | 2 | 2 |
| 003 | 30 | 3 | 3 |
| 004 | 4 | 4 | 4 |
| 005 | 8 | 5 | 5 |
| 006 | 11 | 6 | 6 |
| 007 | 0 | 7 | 7 |
| 008 | 61 | 8 | 8 |
| 009 | 7 | 9 | 9 |

Every sample has `raw_input_uint8.npy`, the preprocessed `input.npy`, Conv,
ReLU, pool, flatten and logits tensors, scalar ground-truth and prediction
arrays, and metadata under `../golden/sample_NNN/`.

## Reproducibility evidence

- Python 3.14.0; PyTorch 2.14.1+cpu; NumPy 2.5.3.
- Shared Python/NumPy/PyTorch seed: 349.
- CPU inference, deterministic PyTorch algorithms, one thread, MKLDNN disabled.
- Two fresh checkpoint reloads and complete regenerations: **PASS**.
- All 147 compared generated files were byte-identical.
- Canonical checked-in output matched fresh regeneration.
- Aggregate generated-tree SHA-256:
  `7d3f776e35997b4000232faeeebbdf104bc7928bc989c9a156a40c1c8bf2ded9`.
- Per-file hashes: `../golden/sha256_manifest.json` and
  `../exports/sha256_manifest.json`.

The desktop software reference is the independent correctness oracle for later
C/C++, CPU and accelerator implementations.
