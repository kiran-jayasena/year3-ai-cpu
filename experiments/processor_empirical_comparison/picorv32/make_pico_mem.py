from pathlib import Path
import struct

p = Path(__file__).resolve().parent / "pico.bin"
data = p.read_bytes()
data += b"\0" * ((4 - len(data) % 4) % 4)
words = [struct.unpack_from("<I", data, i)[0] for i in range(0, len(data), 4)]
(p.parent / "pico.mem").write_text("\n".join(f"{w:08x}" for w in words) + "\n", encoding="ascii")
