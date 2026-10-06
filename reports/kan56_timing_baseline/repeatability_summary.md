# KAN-56 Repeatability Summary

Accepted timing point: **10.752688172 ns / 93.000 MHz** on `sys_clk_pin`.

Three independent implementation runs used the same frozen RTL, target part, XDC, Vivado version, default directives, and clock period:

| Run | WNS (ns) | TNS (ns) | Worst hold slack (ns) | Route | Result |
|---|---:|---:|---:|---|---|
| `p1075268_r1` | +0.230 | 0.000 | +0.059 | PASS | PASS |
| `p1075268_r2` | +0.230 | 0.000 | +0.059 | PASS | PASS |
| `p1075268_r3` | +0.230 | 0.000 | +0.059 | PASS | PASS |

Ranges across repeats:

- WNS: +0.230 to +0.230 ns
- TNS: 0.000 ns on every run
- Worst hold slack: +0.059 to +0.059 ns
- Resources: 2,008 LUTs, 1,812 registers, 2 RAMB18, 5 DSP48, 1 BUFG on every repeat

All three runs routed and generated a bitstream successfully. The accepted point is therefore repeatably timing-clean under the defined criteria.

