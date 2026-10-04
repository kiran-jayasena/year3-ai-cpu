"""Generate the KAN-50 processor-compatible Conv2 representative benchmark."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[3]
PARAM_DIR = ROOT / "software" / "ai_reference" / "exports" / "parameters"
SAMPLE_INDEX = 2
GOLDEN_DIR = ROOT / "software" / "ai_reference" / "golden" / f"sample_{SAMPLE_INDEX:03d}"
PROGRAM_DIR = ROOT / "programs"
REPORT_DIR = ROOT / "reports" / "kan50_processor_benchmark"

IMEM_DEPTH = 256
DMEM_DEPTH = 256
INPUT_BASE = 0
MAGNITUDE_BASE = 36 * 4
SIGN_BASE = 72 * 4
BIAS_BASE = 108 * 4
OUTPUT_BASE = 109 * 4
INPUT_SCALE = 32
WEIGHT_SCALE = 16
PRODUCT_SCALE = INPUT_SCALE * WEIGHT_SCALE

OP = {"NOP": 0x0, "ADD": 0x1, "SUB": 0x2, "AND": 0x3, "OR": 0x4,
      "XOR": 0x5, "ADDI": 0x6, "LOAD": 0x7, "STORE": 0x8,
      "BEQ": 0x9, "JUMP": 0xA}


def enc(op: str, rd: int = 0, rs1: int = 0, rs2: int = 0, imm: int = 0) -> int:
    if not -(1 << 12) <= imm < (1 << 12):
        raise ValueError(f"immediate out of range: {imm}")
    return ((OP[op] & 0xF) << 28) | ((rd & 0x1F) << 23) | ((rs1 & 0x1F) << 18) | ((rs2 & 0x1F) << 13) | (imm & 0x1FFF)


def qround(value: float, scale: int) -> int:
    return int(np.rint(np.float64(value) * scale))


def build_program() -> list[int]:
    program: list[tuple[str, tuple]] = []
    labels: dict[str, int] = {}

    def label(name: str) -> None:
        labels[name] = len(program)

    def emit(op: str, *args) -> None:
        program.append((op, args))

    emit("ADDI", 1, 0, 0, INPUT_BASE)
    emit("ADDI", 2, 0, 0, MAGNITUDE_BASE)
    emit("ADDI", 3, 0, 0, SIGN_BASE)
    emit("ADDI", 11, 0, 0, OUTPUT_BASE)
    emit("LOAD", 12, 0, 0, BIAS_BASE)
    emit("ADDI", 13, 0, 0, 4)
    label("outer")
    emit("ADD", 4, 12, 0)
    emit("ADDI", 10, 0, 0, 9)
    label("inner")
    emit("LOAD", 5, 1, 0, 0)
    emit("LOAD", 6, 2, 0, 0)
    emit("LOAD", 9, 3, 0, 0)
    emit("ADDI", 1, 1, 0, 4)
    emit("ADDI", 2, 2, 0, 4)
    emit("ADDI", 3, 3, 0, 4)
    emit("ADD", 7, 0, 0)
    emit("ADD", 8, 6, 0)
    label("multiply_check")
    emit("BEQ", 0, 8, 0, "multiply_done")
    emit("ADD", 7, 7, 5)
    emit("ADDI", 8, 8, 0, -1)
    emit("JUMP", 0, 0, 0, "multiply_check")
    label("multiply_done")
    emit("BEQ", 0, 9, 0, "positive")
    emit("SUB", 4, 4, 7)
    emit("JUMP", 0, 0, 0, "after_sign")
    label("positive")
    emit("ADD", 4, 4, 7)
    label("after_sign")
    emit("ADDI", 10, 10, 0, -1)
    emit("BEQ", 0, 10, 0, "inner_done")
    emit("JUMP", 0, 0, 0, "inner")
    label("inner_done")
    emit("STORE", 0, 11, 4, 0)
    emit("ADDI", 11, 11, 0, 4)
    emit("ADDI", 13, 13, 0, -1)
    emit("BEQ", 0, 13, 0, "done")
    emit("JUMP", 0, 0, 0, "outer")
    label("done")
    emit("STORE", 0, 11, 4, 0)

    words: list[int] = []
    for index, (op, args) in enumerate(program):
        resolved = []
        for arg in args:
            if isinstance(arg, str):
                resolved.append(labels[arg] - index)
            else:
                resolved.append(arg)
        words.append(enc(op, *resolved))
    if len(words) > IMEM_DEPTH:
        raise AssertionError(f"program uses {len(words)} words, exceeds {IMEM_DEPTH}")
    return words


def write_hex(path: Path, values: list[int], depth: int) -> None:
    padded = values + [0] * (depth - len(values))
    path.write_text("\n".join(f"{value & 0xFFFFFFFF:08x}" for value in padded) + "\n", encoding="ascii")


def main() -> None:
    pool1 = np.load(GOLDEN_DIR / "pool1.npy").astype(np.float64)
    weights = np.load(PARAM_DIR / "conv2_weight.npy").astype(np.float64)
    bias = float(np.load(PARAM_DIR / "conv2_bias.npy")[0])

    input_words: list[int] = []
    magnitudes: list[int] = []
    signs: list[int] = []
    expected: list[int] = []
    for output_y in range(2):
        for output_x in range(2):
            accumulator = qround(bias, PRODUCT_SCALE)
            for ky in range(3):
                for kx in range(3):
                    input_q = qround(pool1[0, output_y + ky, output_x + kx], INPUT_SCALE)
                    weight_q = qround(weights[0, 0, ky, kx], WEIGHT_SCALE)
                    input_words.append(input_q)
                    magnitudes.append(abs(weight_q))
                    signs.append(1 if weight_q < 0 else 0)
                    accumulator += input_q * weight_q
            expected.append(accumulator)

    data = [0] * DMEM_DEPTH
    data[INPUT_BASE // 4:INPUT_BASE // 4 + 36] = input_words
    data[MAGNITUDE_BASE // 4:MAGNITUDE_BASE // 4 + 36] = magnitudes
    data[SIGN_BASE // 4:SIGN_BASE // 4 + 36] = signs
    data[BIAS_BASE // 4] = qround(bias, PRODUCT_SCALE)

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    PROGRAM_DIR.joinpath("kan50_conv2_tile.mem").write_text("", encoding="ascii")
    write_hex(PROGRAM_DIR / "kan50_conv2_tile.mem", build_program(), IMEM_DEPTH)
    write_hex(PROGRAM_DIR / "kan50_conv2_tile_data.mem", data, DMEM_DEPTH)
    write_hex(PROGRAM_DIR / "kan50_conv2_tile_golden.mem", expected, 4)

    metadata = {
        "source_layer": "Conv2",
        "source_sample_index": SAMPLE_INDEX,
        "output_channel": 0,
        "input_channel": 0,
        "output_tile": {"y": [0, 1], "x": [0, 1]},
        "mac_equivalent_operations": 36,
        "input_shape": [4, 13, 13],
        "weight_shape": [8, 4, 3, 3],
        "selected_input_shape": [4, 4],
        "selected_weight_shape": [3, 3],
        "input_scale": INPUT_SCALE,
        "weight_scale": WEIGHT_SCALE,
        "product_scale": PRODUCT_SCALE,
        "rounding": "IEEE-754 binary64 conversion followed by round-to-nearest-even",
        "overflow": "32-bit two's-complement wrap; proven absent for this generated dataset",
        "accumulator": "signed 32-bit integer",
        "multiply": "software repeated addition of input magnitude, with conditional subtraction for negative weights",
        "program_words": len(build_program()),
        "data_words_used": 114,
        "expected_outputs": expected,
        "input_q_values": input_words,
        "weight_q_values": [sign * magnitude if sign == 0 else -magnitude for magnitude, sign in zip(magnitudes, signs)],
        "bias_q": qround(bias, PRODUCT_SCALE),
        "files": {
            "program": "programs/kan50_conv2_tile.mem",
            "data": "programs/kan50_conv2_tile_data.mem",
            "golden": "programs/kan50_conv2_tile_golden.mem",
        },
    }
    (REPORT_DIR / "golden_reference.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, indent=2))


if __name__ == "__main__":
    main()
