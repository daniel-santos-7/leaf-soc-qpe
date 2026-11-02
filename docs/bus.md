# Bus & Interconnect
The core has two Wishbone B4 masters, one for instruction fetch and one for data; the SPI debug bridge is a third master that shares the data channel. All of them are pipelined masters (`STB` for one cycle, `ACK` awaited with `CYC` held) and use `SEL` and `ERR`.

`wb_intercon` connects them to the slaves as a partial crossbar:

| Master | ROM | XIP B | RAM0 B | RAM1 B | UART | IO1 | GPIO | XIP A | RAM0 A | RAM1 A |
|--------|:---:|:-----:|:------:|:------:|:----:|:---:|:----:|:-----:|:------:|:------:|
| Instruction | ✓ | ✓ | ✓ | ✓ | | | | | | |
| Data | | | | | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Debug (via data) | | | | | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

The two slave sets are disjoint, so the CPU channels run in parallel with no arbitration. Each RAM and the XIP controller have two slave interfaces, B for instruction and A for data, so a fetch and a load/store can complete in the same cycle. The debug bridge enters the data channel through `wb_arbiter` (see [Debug Bridge](debug-bridge.md)).

`wb_intercon` holds one `wb_channel` per master, which decodes the address against `leaf_soc_pkg`:

- **Responses** are steered by a registered select, held until the addressed slave answers, so there is one transfer in flight per channel and a slave may take any number of cycles. Single-cycle slaves still run at one transfer per cycle.
- **Errors:** an unmapped address, or a slave not routed to that master (a load from ROM, a fetch from the UART), answers `ERR` one cycle later and the CPU takes an access fault.
- **Stall** is raised while a response is outstanding or while the addressed slave raises its own `STALL`. Only the XIP fetch port and RAM1's data port (see [Macro-based RAM](memory.md#macro-based-ram)) ever do.

Every slave accepts a request on every cycle, with no gating on its pending `ACK`. Routing a slave to another master means connecting its port group on that master's `wb_channel`, plus an arbiter once two masters can reach it.
