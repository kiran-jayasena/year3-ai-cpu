# KAN-50 memory footprint

The candidate CPU memories remain unchanged at 256 words each, with 32-bit words.

## Instruction memory

- Generated program words: 33
- Program bytes: 132
- Capacity: 256 words / 1,024 bytes
- Remaining capacity: 223 words / 892 bytes

## Data memory

- 36 quantised input words: 144 bytes
- 36 weight-magnitude words: 144 bytes
- 36 weight-sign words: 144 bytes
- 1 bias word: 4 bytes
- 4 output words: 16 bytes
- 1 sentinel output word: 4 bytes
- Total used: 114 words / 456 bytes
- Capacity: 256 words / 1,024 bytes
- Remaining capacity: 142 words / 568 bytes

All values are 32-bit little-endian `$readmemh` words. The data image is loaded into the existing BRAM instance by the benchmark testbench; no RTL memory change is made.

