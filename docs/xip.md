# XIP Controller
`wb_xip_ctrl` turns each instruction fetch in `0x20000000`–`0x20FFFFFF` into one SPI Read (`03h`): command, 24-bit address and 32 data bits in a single 64-bit frame, SPI mode 0, MSB first. The flash sends the lowest address first, so the word is byte-swapped for the little-endian CPU. Frames go out through the master role of the shared SPI port (see [SPI Pins](spi-pins.md)), and the instruction master is stalled for the whole read.

**Configuration register** at `0x20FFFFFC`, on the data port. Any other data access in the window answers `ERR`, so XIP is fetch-only.

| Bits | Field | Access | Reset | Description |
|------|-------|--------|-------|-------------|
| 0 | `EN` | RW | 0 | Gives the SPI port to XIP (master role) |
| 1 | `ACT` | RO | 0 | The master role is in effect and XIP takes fetches |
| 15–8 | `CS_HIGH` | RW | `XIP_CS_HIGH_CYCLES` | Minimum `CS#` high time between reads, in cycles (never less than 5) |
| 23–16 | `SCK_DIV` | RW | `XIP_SCK_DIV - 1` | SCK half-period is `SCK_DIV + 1` cycles |

The other bits read 0. Each field has a byte of its own, so a byte store changes one field. `SCK_DIV` and `CS_HIGH` apply from the next fetch and can be written while code runs from XIP.

**Enabling:** set `EN`, wait for `ACT`, then jump into XIP. A fetch while `ACT` is clear answers `ERR` and the CPU takes an instruction access fault. Code running from XIP may clear `EN`: it keeps running, and the port goes back to the debug bridge once the code jumps to RAM. While `EN` is 1 the debug bridge cannot be reached.

**Timing:** the flash is not chosen yet, so the reset values in `leaf_soc_pkg`, `XIP_SCK_DIV = 2` and `XIP_CS_HIGH_CYCLES = 10`, are conservative for any 3.3 V SPI NOR at the 100 MHz system clock:

| Datasheet figure | Typical range | Default at 100 MHz |
|---|---|---|
| Maximum SCK of the `03h` read | about 25 MHz on older parts, 50–55 MHz on current ones | 25 MHz |
| tCLQV (SCK fall to MISO valid), plus pad and board delays | 6–8 ns plus a few ns | 20 ns sampling window |
| tSHSL (minimum `CS#` high) | about 10–50 ns, up to 100 ns on older parts | 100 ns |

A word takes `128 × (SCK_DIV + 1) + 4` cycles from request to `ACK` (260 with the defaults), so code in XIP runs about two orders of magnitude slower than from RAM. Once the flash and the board are known, software can speed it up through `SCK_DIV` and `CS_HIGH`.

In simulation the flash model holds a copy of the program binary (512 KB, addresses wrap), so position-independent code at `0x90000000 + n` can also be called at `0x20000000 + n`. `sw/c/xip_test` does that and prints `XIP ram=0efff9dc xip=0efff9dc ok` in about 1M cycles.
