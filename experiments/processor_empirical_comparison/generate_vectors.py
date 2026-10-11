"""Generate deterministic N=16/N=128 comparison vectors and goldens."""

from pathlib import Path
import json

ROOT = Path(__file__).resolve().parent

N16_A = [3, -2, 5, -4, 7, -1, 2, -6, 4, -3, 1, -5, 6, -7, 0, 8]
N16_B = [-3, 4, -1, -2, 2, -5, 6, 3, -4, 7, -8, 1, -2, 5, 9, -1]


def signed32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - (1 << 32) if value & 0x80000000 else value


def dot(a: list[int], b: list[int]) -> int:
    assert len(a) == len(b)
    return signed32(sum(x * y for x, y in zip(a, b)))


def write_csv(path: Path, a: list[int], b: list[int]) -> None:
    path.write_text("index,a,b\n" + "".join(f"{i},{x},{y}\n" for i, (x, y) in enumerate(zip(a, b))), encoding="utf-8")


def write_mem(path: Path, values: list[int]) -> None:
    path.write_text("".join(f"{value & 0xFFFFFFFF:08x}\n" for value in values), encoding="ascii")


def make_n128() -> tuple[list[int], list[int]]:
    # Small signed-int8 values keep the scalar software-multiply benchmark
    # within the frozen 256-word instruction/data-memory limits. The sign of b
    # alternates, so the benchmark still exercises signed accumulation.
    a = [((17 * i + 3) % 8) + 1 for i in range(128)]
    b = [((29 * i + 5) % 8) + 1 for i in range(128)]
    b = [value if i % 2 == 0 else -value for i, value in enumerate(b)]
    return a, b


def emit_case(name: str, a: list[int], b: list[int]) -> None:
    result = dot(a, b)
    case_dir = ROOT / name
    case_dir.mkdir(parents=True, exist_ok=True)
    write_csv(case_dir / "vectors.csv", a, b)
    write_mem(case_dir / "a_words.mem", a)
    write_mem(case_dir / "b_words.mem", b)
    (case_dir / "golden.mem").write_text(f"{result & 0xFFFFFFFF:08x}\n", encoding="ascii")
    (case_dir / "metadata.json").write_text(json.dumps({
        "vector_length": len(a),
        "mac_count": len(a),
        "operand_type": "signed int8",
        "accumulator_type": "signed int32 modulo 2^32",
        "expected_signed": result,
        "expected_hex": f"0x{result & 0xFFFFFFFF:08X}",
        "layout": "canonical signed values; one word per operand in reference memory images",
    }, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    emit_case("n16", N16_A, N16_B)
    emit_case("n128", *make_n128())
    manifest = {
        "n16_expected_hex": f"0x{dot(N16_A, N16_B) & 0xFFFFFFFF:08X}",
        "n128_expected_hex": f"0x{dot(*make_n128()) & 0xFFFFFFFF:08X}",
        "cases": ["n16", "n128"],
    }
    (ROOT / "vectors_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
