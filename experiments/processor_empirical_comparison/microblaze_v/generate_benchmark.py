from pathlib import Path
import csv

root = Path(__file__).resolve().parents[1]
out = Path(__file__).resolve().parent / "software"
out.mkdir(parents=True, exist_ok=True)

def load(n):
    with (root / f"n{n}" / "vectors.csv").open(newline="") as f:
        rows = list(csv.DictReader(f))
    return [int(r["a"]) for r in rows], [int(r["b"]) for r in rows]

def c_array(name, values):
    return f"static const int8_t {name}[{len(values)}] = {{{', '.join(map(str, values))}}};\n"

a16, b16 = load(16)
a128, b128 = load(128)
source = """#include <stdint.h>

#define RESULT_MMIO (*(volatile uint32_t *)0x00007ffcU)
#define STATUS_MMIO (*(volatile uint32_t *)0x00007ff8U)

static inline uint32_t read_cycle(void) {{ uint32_t v; __asm__ volatile ("csrr %0, cycle" : "=r"(v)); return v; }}
static inline uint32_t read_instret(void) {{ uint32_t v; __asm__ volatile ("csrr %0, instret" : "=r"(v)); return v; }}

{a16}{b16}{a128}{b128}
static int32_t dot(const int8_t *a, const int8_t *b, uint32_t n) {{
    int32_t sum = 0;
    for (uint32_t i = 0; i < n; ++i) sum += (int32_t)a[i] * (int32_t)b[i];
    return sum;
}}

static void run_case(const int8_t *a, const int8_t *b, uint32_t n, uint32_t expected) {{
    uint32_t c0 = read_cycle();
    uint32_t i0 = read_instret();
    int32_t result = dot(a, b, n);
    uint32_t i1 = read_instret();
    uint32_t c1 = read_cycle();
    RESULT_MMIO = (uint32_t)result;
    STATUS_MMIO = (result == (int32_t)expected) ? 0x600D0000U : 0xBAD00000U;
    STATUS_MMIO = (c1 - c0);
    STATUS_MMIO = (i1 - i0);
}}

int main(void) {{
    run_case(a16, b16, 16U, 0xffffff96U);
    run_case(a128, b128, 128U, 0x00000240U);
    for (;;) {{ __asm__ volatile ("wfi"); }}
    return 0;
}}
""".format(a16=c_array("a16", a16), b16=c_array("b16", b16), a128=c_array("a128", a128), b128=c_array("b128", b128))
(out / "dotprod.c").write_text(source, encoding="ascii")
(out / "benchmark_metadata.txt").write_text("Generated from existing n16/n128 vectors.csv; signed int8 operands; signed int32 accumulator; expected N16=0xFFFFFF96; N128=0x00000240.\n", encoding="ascii")
