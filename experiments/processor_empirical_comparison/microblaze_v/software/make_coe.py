from pathlib import Path
import struct

here = Path(__file__).resolve().parent

def make(name, binary, byte_address, depth=8192):
    data = (here / binary).read_bytes()
    if len(data) % 4:
        data += b"\0" * (4 - len(data) % 4)
    words = [0] * depth
    start = byte_address // 4
    for i in range(0, len(data), 4):
        if start + i // 4 >= depth:
            raise ValueError(f"{binary} exceeds BRAM")
        words[start + i // 4] = struct.unpack_from("<I", data, i)[0]
    lines = [f"{w:08X}" for w in words]
    (here / name).write_text("memory_initialization_radix=16;\nmemory_initialization_vector=\n" + ",\n".join(lines) + ";\n", encoding="ascii")

make("imem.coe", "text.bin", 0x24)
make("dmem.coe", "rodata.bin", 0x7000)
