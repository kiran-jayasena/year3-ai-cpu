from pathlib import Path
import struct

here = Path(__file__).resolve().parent

def make(name, binary, byte_address, depth=8192):
    data = (here / binary).read_bytes()
    data += b"\0" * ((4 - len(data) % 4) % 4)
    words = [0] * depth
    start = byte_address // 4
    for i in range(0, len(data), 4):
        words[start + i // 4] = struct.unpack_from("<I", data, i)[0]
    (here / name).write_text("\n".join(f"{w:032b}" for w in words) + "\n", encoding="ascii")

make("imem.mif", "text.bin", 0x0)
make("dmem.mif", "rodata.bin", 0x7000)
