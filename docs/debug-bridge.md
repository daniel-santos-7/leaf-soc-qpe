# Debug Bridge
The debug bridge is an SPI slave on the shared pins that turns each frame into a Wishbone transfer on the data channel. It reaches everything the data master reaches (UART, IO1, GPIO, the XIP configuration register, RAM0 and RAM1) while a program runs, and can hold the CPU in reset to load a program. It cannot see the CPU's registers or PC, nor set breakpoints: the core has no debug port.

**SPI:** mode 0, MSB first, one 64-bit frame per `CS#` low. The pins are oversampled by the system clock, so SCK must stay at least 5 cycles high and 5 low (SCK ≤ clk/10), the first SCK rise must come at least 5 cycles after `CS#` falls, and `CS#` must stay high for at least 2 cycles between frames. A shorter frame reports `ERR`, bits past the 64th are ignored, and an empty frame (`CS#` with no SCK) is ignored.

A frame is a command word (bits 63–32) followed by a data word (bits 31–0):

| Command word | Op | Data word | Action |
|--------------|----|-----------|--------|
| `addr[31:2]` & `00` | READ | — | word read at `addr`; the result is the data (0 on `ERR`) |
| `addr[31:2]` & `01` | WRITE | data | word write at `addr`; the result is 0 |
| `0` & `00` & `10` | CTRL RUN | — | `HALT` = 0; the result is 0 |
| `0` & `01` & `10` | CTRL HALT | — | `HALT` = 1; the result is 0 |
| `0` & `10` & `10` | CTRL ID | — | the result is `0x4C454146` (`DBG_ID`) |
| `x` & `11` | NOP | — | nothing; the result is left alone |

CTRL subcommand `11` is reserved and reports `ERR`. Transfers are whole words (`SEL = 1111`), so a byte register needs a read-modify-write.

**Reply:** every frame carries the reply to the frame before it, so reads are pipelined: send READ `addr`, then any command (NOP if nothing else), whose reply holds the data. The first frame after reset carries the initial status. The reply is the status word (bits 63–32) followed by the result word (bits 31–0):

| Bit | Status | Meaning |
|-----|--------|---------|
| 31 | `READY` | 1: this frame's command runs. 0: it arrived too early, while a READ or WRITE was still in progress, and was dropped; send it again |
| 30 | `ACK` | the last command completed |
| 29 | `ERR` | the last command failed (short frame, reserved CTRL, or a bus `ERR` such as an unmapped address or the ROM) |
| 28 | `HALT` | the CPU is held in reset |

A host that keeps `CS#` high for one SCK period between frames gets READ data in the very next frame.

**Arbitration:** `wb_arbiter` shares the data channel between the CPU and the bridge. The bridge wins ties, which cannot starve the CPU since it issues at most one transfer per frame.

**HALT** holds the CPU in reset, and in COP mode the pulse generator with it; the peripherals, the RAMs and the bus keep running. It is cleared when the port leaves the slave role, so setting `EN` (from software or by a debug WRITE) always releases the CPU. To load a program: `HALT = 1`, WRITE the image into RAM1, `HALT = 0`; the boot ROM then waits for `RAM1_JUMP_CMD` on the UART.
