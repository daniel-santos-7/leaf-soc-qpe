# :leaves: Leaf SoC

Leaf SoC is a compact and efficient 32-bit *System-on-Chip* based on the RISC-V architecture. It is designed for embedded applications, IoT (Internet of Things), and academic research, providing a balanced platform between resource economy and functional completeness.

This repository carries the SoC together with a **QPE** (Quantum Pulse Extension): the CPU drives a DDS waveform generator that emits Gaussian, DRAG-corrected I/Q pulses for qubit control.

## :star: Features

- **Leaf Processor:** 32-bit RISC-V core (RV32I) with a 2-stage pipeline.
- **Wishbone B4 Bus:** Crossbar interconnect; instruction fetch and data accesses run in parallel.
- **Memory System:** Integrated Boot ROM, two internal dual-port RAMs: RAM0 (32 KB) and RAM1 (1 KB).
- **Standard Peripherals:** UART for serial communication and an 8-pin GPIO with edge interrupts.
- **Pulse Generator:** DDS signal generator with Gaussian envelopes and DRAG correction, reachable either as a coprocessor or as a memory-mapped peripheral.
- **Debug Bridge:** SPI slave that reads and writes the data bus and holds the CPU in reset, with no change to the core.
- **Expandability:** Ready for XIP (Execute-In-Place) and custom hardware via a dedicated coprocessor interface.
- **FPGA Friendly:** Synthesizable VHDL design optimized for modern FPGA architectures.

## :gears: Microarchitecture

The SoC architecture is centered around the **Wishbone B4** interconnect, which manages the communication between the Leaf core's two masters and the slave peripherals.

### Processor
The **Leaf** core implements the RV32I base integer instruction set. It features a 2-stage pipeline (Fetch and Execute) and supports Machine-mode CSRs, hardware counters, and interrupts.

### Bus & Interconnect
The Leaf core is Harvard: it has two Wishbone B4 masters, one for instruction fetch and one for data. A third master, the SPI debug bridge, shares the data channel with the core. Both drive the bus as **pipelined** masters: `STB` is asserted for a single cycle and `ACK` is awaited with `CYC` held. Byte selects (`SEL`) and error reporting (`ERR`) are supported.

A single **Intercon** (`wb_intercon`) connects both masters to the slaves as a partial crossbar:

| Master | ROM | XIP | RAM0 B | RAM1 B | UART | IO1 | GPIO | RAM0 A | RAM1 A |
|--------|:---:|:---:|:------:|:------:|:----:|:---:|:----:|:------:|:------:|
| Instruction | ✓ | ✓ | ✓ | ✓ | | | | | |
| Data | | | | | ✓ | ✓ | ✓ | ✓ | ✓ |
| Debug (via data) | | | | | ✓ | ✓ | ✓ | ✓ | ✓ |

The instruction and data sets of slaves are disjoint, so the two CPU channels run in parallel with no arbitration between them. The debug bridge reaches exactly the data set, through `wb_arbiter` in front of the data `wb_channel` (see Debug Bridge). Each dual-port RAM appears as two slave interfaces, which is what lets a fetch and a load/store complete in the same cycle. Both are instances of the same `wb_ram_dp`: RAM0 with `BITS => 15`, RAM1 with `BITS => 10`.

`wb_intercon` is structural: one **`wb_channel`** per master, i.e. per CPU channel. `wb_channel` has a port group for every slave in the memory map (`rom_*`, `io0_*`, `io1_*`, `io2_*`, `xip_*`, `ram0_*`, `ram1_*`) and decodes them against the bases and widths in `leaf_soc_pkg`. The regions are disjoint, which keeps the select one-hot. Each instance connects the slaves routed to its master and ties off the others: their outputs are left `open`, and their inputs are tied to `ACK = '0'`, `ERR = '1'` and zero data.

Inside `wb_channel`:

- **Forward path:** combinational. A slave's `STB` is the master's `STB` gated by the decode of the current address.
- **Response path:** `ACK`, `ERR` and read data are steered by a *registered* select, captured in the request cycle. That way a pipelined master that moves to a new address every cycle still gets each response matched to the request that produced it. The select is only captured while `CYC and STB` is high; otherwise a stale select would survive into idle cycles and could let a phantom `ACK` through.
- **Unrouted accesses:** a tied-off slave answers through its fixed `ERR = '1'`, gated by the registered select like any response, and an address outside the map is answered by the decoder itself. Either way `ERR` arrives one cycle after the request (a load from ROM, a fetch from the UART, an unmapped address), and the CPU takes an access-fault trap instead of waiting for an `ACK` that never comes. A slave with no error signal of its own, when routed, has its `ERR` input tied to `'0'`.
- **Stall:** each channel drives its master's `STALL`. It is high while an XIP transfer is outstanding: `xip_sel_reg` is set when the XIP request is accepted and held until the XIP `ACK`, and while it is high the channel gates its own `req` and every slave's `STB`, so the master keeps its next request pending and nothing can overtake the slow response. Everywhere else it stays `'0'`: no other slave inserts wait states, and `wb_sig_gen`'s `stall_o`, tied low, is left open.

The response path assumes every slave acknowledges exactly one cycle after its strobe. This holds for the ROM, the ports of both RAMs, the UART and the GPIO. XIP is the exception, and the stall above is what makes it work: its select is held instead of being recaptured every cycle, so there is only ever one XIP request in flight and its `ACK` is matched to it no matter how late it comes.

Every slave also accepts a new request on every cycle, with no gating on its own pending `ACK`. A classic slave that writes only while its `ACK` is low would, behind a pipelined master, drop the second of two requests on consecutive cycles and still acknowledge it; `wb_ram_dp` therefore guards its port-A write with the request alone.

### XIP Controller
`wb_xip_ctrl` turns each instruction fetch in `0x20000000`–`0x20FFFFFF` into one SPI Read (`0x03`) of four bytes: command, 24-bit address, 32 data bits, 64 SCK periods in all. It uses SPI mode 0. `CS#` falls together with the first MOSI bit, MOSI changes on SCK falling edges, and MISO is sampled in the system cycle in which SCK rises. SCK, MOSI and `CS#` all come straight from flip-flops. The pins are shared with the debug bridge (see SPI Pins below).

It is two modules. `spi_master`, from the [`ips/spi`](ips/spi/) IP (inside `spi_port`, see SPI Pins), drives the pins and runs one fixed-length frame per `start`: `SPI_WIDTH` (64) bits out, 64 bits in, with `rx_valid` in the first cycle after `CS#` rises. It holds `SCK_DIV`, `CS_HIGH_CYCLES` and the hold counter; the shift registers are a single `spi_shift` inside `spi_port`, `SPI_WIDTH` (64) bits wide, shared with the debug slave since only one role is active at a time. It knows nothing about flash commands (see the IP's README). `wb_xip_ctrl` (`soc_xip`) is the Wishbone side: on a request it starts a frame of `03h`, the 24-bit address and 32 zero bits, and drives `ACK` combinationally on `rx_valid`, with the low 32 received bits byte-swapped onto `DAT` (the flash sends the byte at the lowest address first, and the CPU is little-endian). If the `CS#` hold is not over yet, the controller latches the address and keeps `start` up until the master is ready. The timing is the same as the byte-stream version it replaced (`CS#` edges compared cycle for cycle in `xip_test` with the defaults and with `SCK_DIV = 2`, `CS_HIGH_CYCLES = 4`).

Two generics of `spi_master` set the SPI timing, from `XIP_SCK_DIV` and `XIP_CS_HIGH_CYCLES` in `leaf_soc_pkg`:

- **`SCK_DIV`:** SCK stays `SCK_DIV` system cycles high and `SCK_DIV` low, and the first SCK rise comes `SCK_DIV` cycles after `CS#` falls. MISO is sampled `SCK_DIV` cycles after the falling edge that launched it, which is the window the flash's tCLQV plus pad and board delays must fit in.
- **`CS_HIGH_CYCLES`:** `CS#` stays high for at least this many cycles between two reads (2 at minimum). A request that arrives earlier has its address latched by `wb_xip_ctrl`, which keeps `start` up until `spi_master` is ready, with `CS#` still high.

The defaults, 1 and 2, give SCK at half the system clock and 20 ns of `CS#` high at 100 MHz. Set both from the chosen flash's datasheet: the maximum SCK frequency of the `03h` read bounds `SCK_DIV`, and tSHSL bounds `CS_HIGH_CYCLES`. A word takes `128 × SCK_DIV + 2` cycles from request to `ACK` (130 with the defaults), plus whatever `CS#` hold is still pending, and the instruction master is stalled for all of it, so code in XIP runs roughly two orders of magnitude slower than from RAM.

XIP is fetch-only. The controller has no write path and no `ERR`, and the data channel keeps XIP tied off, so a load or store there takes an access fault. In simulation the testbench's `spi_flash_model` holds a copy of the program binary (512 KB, addresses wrap), so a function at `0x80000000 + n` can also be called at `0x20000000 + n` if its code is position-independent. `sw/c/xip_test` does exactly that and compares the result with the RAM0 call (`XIP ram=0efff9dc xip=0efff9dc ok`); it needs about 500k cycles with the defaults, and 1M is enough with `SCK_DIV = 2`.

Routing a slave to a master means connecting its port group on that master's `wb_channel` instead of tying it off. A new slave in the memory map needs a port group in `wb_channel`. A slave reachable from both masters also needs an arbiter in front of it.

### Memory Map
The default address space allocation is defined as follows:

| Peripheral | Base Address | Size | Description |
|------------|--------------|------|-------------|
| **ROM**    | `0x00001000` | 512 B | Bootloader / Initialization code |
| **UART**   | `0x10000000` | 16 B | Serial communication (IO0) |
| **IO1**    | `0x10001000` | 32 B | Pulse generator CSRs (MMIO mode only) |
| **GPIO**   | `0x10002000` | 64 B | General-purpose I/O, 8 pins (IO2) |
| **XIP**    | `0x20000000` | 16 MB | External Flash / Execute-In-Place (Optional) |
| **RAM0**   | `0x80000000` | 32 KB | Main System Memory (dual-port: A = data, B = instruction) |
| **RAM1**   | `0x90000000` | 1 KB | Secondary memory (dual-port: A = data, B = instruction) |

Bases and widths are declared once in [`soc/rtl/leaf_soc_pkg.vhdl`](soc/rtl/leaf_soc_pkg.vhdl), which is the source of truth for the map.

Programs are linked into RAM0 (`sw/*/common/soc.ld`). RAM1 is declared there as a second region with a `.ram1` section, which is `NOLOAD`: a loadable section at `0x90000000` would make `objcopy -O binary` pad the `.bin` across the 256 MB gap from RAM0. So RAM1 is never preloaded and `crt0` does not clear it, and its contents are undefined until the program writes them. Put data there with `__attribute__((section(".ram1")))`. Code must be copied in at run time, and the instruction master can then fetch it. `sw/c/ram1_test` sweeps the whole region with word, half-word and byte accesses, prints a checksum (`d2072fde`) and an error count, then copies two instructions in and calls them (`exec=42`). In simulation `soc_ram1` binds to the synthesis `wb_ram_dp`, not a preloading model.

### GPIO
The GPIO is the [`wb-gpio`](https://github.com/daniel-santos-7/wb-gpio) IP (submodule `ips/gpio`), instantiated with `G_WIDTH => GPIO_WIDTH` (8, in `leaf_soc_pkg`) on IO2, which only the data master reaches. It is a pipelined slave with a one-cycle `ACK` and no `ERR`, like the UART, and its `stall_o`, constant `'0'`, is left open.

| Offset | Register | Access | Description |
|--------|----------|--------|-------------|
| `0x00` | DATA_IN    | RO    | Synchronised pin values (2 flip-flops) |
| `0x04` | DATA_OUT   | RW    | Value driven on output pins |
| `0x08` | DIR        | RW    | 1 = output, 0 = input |
| `0x0C` | SET        | WO    | `DATA_OUT \|= wdata` |
| `0x10` | CLR        | WO    | `DATA_OUT &= ~wdata` |
| `0x14` | TGL        | WO    | `DATA_OUT ^= wdata` |
| `0x18` | IRQ_RISE   | RW    | Rising-edge interrupt enable |
| `0x1C` | IRQ_FALL   | RW    | Falling-edge interrupt enable |
| `0x20` | IRQ_STATUS | R/W1C | Pending events; writing 1 clears |

`leaf_soc` brings the pins out as three vectors, `gpio_i`, `gpio_o` and `gpio_oe` (1 = drive), and leaves the tri-state buffer to the padframe or the board. The GPIO's `irq_o` drives the CPU's external interrupt input (`ex_irq_i`, `mip.MEIP`), the only interrupt source in the SoC; it stays high while any `IRQ_STATUS` bit is set, so a handler must clear the status before returning. Software must also set `mtvec` itself: nothing in `sw/` does by default (see [#4](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/4)).

Software reaches it through `sw/c/common/gpio.c`/`gpio.h`, which a program adds to `APP_SRC` like the pulse APIs: `gpio_set_dir`/`gpio_get_dir`, `gpio_get_in`, `gpio_set_out`/`gpio_get_out`, the atomic `gpio_set_bits`/`gpio_clr_bits`/`gpio_tgl_bits`, and `gpio_set_irq_rise`/`gpio_set_irq_fall`, `gpio_get_irq_status` and `gpio_clr_irq_status` (write 1 to clear). Arguments are pin masks, bit *n* for pin *n*. Assembly has the same calls as macros in `sw/asm/common/gpio.inc` (`gpio.set_dir s0`, `gpio.get_in a0`, …, symbols `GPIO_BASE`/`GPIO_OFF_*`): a setter takes the register holding the value, a getter the destination register, and every macro uses `t6` for the base, so `t6` cannot be a setter's argument. `sw/asm/gpio-test` repeats the pin and SET/CLR/TGL checks of `gpio_test`, then checks `IRQ_STATUS` and its W1C clear by polling, without taking the interrupt, and prints `GPIO asm ok`. Both APIs cover the peripheral only: taking the interrupt still means setting `mtvec`, `mie.MEIE` and `mstatus.MIE`, as `gpio_test` does.

In the testbench each pin reads back its own output when `gpio_oe` is set and the constant `0xA5` otherwise. `sw/c/gpio_test` exercises the pins and the SET/CLR/TGL registers, then enables a rising-edge interrupt on pin 1 and takes it through `mtvec`. It prints `in=aa`, `af`, `ac`, `a5` and `irq count=1 status=02 mcause=8000000b pending=00`, and needs about 1.2M cycles to finish printing.

### Macro-based RAM
`wb_ram_dp_macro` is a drop-in alternative to `wb_ram_dp` for RAM0 that builds the 32 KB out of hard SRAM macros instead of an inferred array: eight 2048 x 16 dual-port macros, four banks in depth by two halves in width. It has the same ports and the same pipelined contract as `wb_ram_dp` (one-cycle `ACK`, a write accepted on every request cycle). The low `MACRO_ADDR_BITS` (11) bits of the word address index inside a macro and the bits above select the bank; only the addressed bank is enabled. `sel_a_i` becomes an active-high per-bit write mask, one byte lane at a time, `sel_a_i(0..1)` into the low half and `sel_a_i(2..3)` into the high one. Port B is tied read-only because it serves the instruction master.

The macros are reached through `sram_dp`, a technology-neutral interface declared once in `soc/rtl/sram_dp.vhdl`: per port a clock, `en`, `we`, `wmask`, `addr`, `d` and `q`, all active high. Its contract is that of a synchronous SRAM: one cycle of read latency, and `q` changes only on a read cycle, so a write or an idle port holds the last value read. That is why the wrapper registers the bank of each read to steer the output mux on the `ACK` cycle. A read that meets a write to the same word on the other port returns unknowns, and two writes to one word corrupt the bits both of them enable. The entity also carries `INIT_FILE`, `INIT_BANK` and `INIT_HALF`, which only a simulation architecture uses. `wb_ram_dp_macro` instantiates `sram_dp` as a component so that a configuration can pick the architecture:

- `soc/tbs/sram_dp_sim.vhdl` holds architecture `sim`, a behavioural model of that contract. With `INIT_FILE` set it zero-fills the array and loads the half-words of its bank from a raw little-endian image; with `INIT_FILE = ""` the array powers up unknown.
- A technology architecture maps `sram_dp` onto a real macro's pins. It is not part of this repository: it lives in the directory named by `TECH_DIR` (default `tech/`, which is gitignored), because the macro, its model and its documentation come from a memory compiler under NDA.

`RAM` selects what the testbench binds to `soc_ram0`, as a different top-level configuration rather than a source edit:

| `RAM` | Top | RAM0 |
|-------|-----|------|
| `BEHAV` | `leaf_soc_tb_sim` | `wb_ram_dp_sim`, the inferred array |
| `MACRO` | `leaf_soc_tb_macro` | `wb_ram_dp_macro` over `sram_dp(sim)` |
| `TECH` | `leaf_soc_tb_tech` | `wb_ram_dp_macro` over the technology architecture |

`MACRO` goes through `wb_ram_dp_macro_sim`, which instantiates the configuration `wb_ram_dp_macro_preloaded`: it binds each macro to `sram_dp(sim)` with its bank and half preloaded from `work/program.bin`, so the `RAM_JUMP_CMD` shortcut still applies. A configuration has no loop, so the four banks are spelled out, and `wb_ram_dp_macro_sim` asserts `BITS = 15` rather than silently preloading part of the RAM. Every configuration lives in its own file, one top per file, so that each top's dependency closure stays separate. For `TECH`, the directory must supply the technology architecture of `sram_dp` and a configuration `leaf_soc_tb_tech`; the Makefile adds its `*.vhdl` files to the build when it exists and refuses `RAM=TECH` when it does not. RAM1 always uses `wb_ram_dp`: at 256 words it is smaller than one macro.

Synthesis works the same way. `leaf_soc` instantiates `soc_ram0` as the `wb_ram_dp` component, so synthesising `leaf_soc` directly gives the inferred array. To get the macros, synthesise a configuration of `leaf_soc` that binds `soc_ram0` to `wb_ram_dp_macro` and `sram_dp` to the technology architecture, leaving the macro cell itself unbound so it becomes a black box. That configuration lives with the technology files too. RAM1 stays on `wb_ram_dp` in synthesis as well, by design: its 8 Kbit are built as flip-flops rather than a macro.

`sw/c/ram_test` checks the array end to end. It sweeps the free part of RAM0, which crosses all four banks, with word stores, then byte and half-word stores on every fourth word, then a store followed at once by a load of the same word. It reads everything back and prints an order-dependent checksum and an error count, so a bank-decode or write-mask fault moves the checksum. It must not call `uart_init`, since rewriting the baud divisor corrupts the ACK the boot ROM still has in flight when it jumps to RAM, and the checksum avoids `*` because a software multiply on rv32i would dominate the run. It needs about 6M cycles and prints `checksum 9A1081FB`, `errors 00000000` under every `RAM`:

```bash
make -C sw/c/ram_test
make run PROGRAM=sw/c/ram_test/ram_test.bin RAM=MACRO RUN_CYCLES=6000000
```

RAM0's two ports share one clock, so a store on port A and an instruction fetch on port B can hit the same word in the same cycle. The store lands, but the fetch does not get a defined word: `wb_ram_dp` returns the old word, `sram_dp(sim)` returns unknowns, and a real macro is undefined there and also specifies a minimum clock separation between its ports for the same address. Both simulation models print a warning when it happens (`wb_ram_dp_sim` under `RAM=BEHAV`, `sram_dp(sim)` under `RAM=MACRO`), so a colliding program shows up even in the default runs. With this core it has not been seen: in straight-line code, right after a jump and with the store as the jump target, the fetch was three words ahead with its buffer full in the cycle the store reached the bus. That is a property of the fetch unit, not a guarantee, so software must not store into instruction words inside the prefetch window (the few words after the PC). After writing code, jump to it, since a jump discards what was fetched, and do not rely on `FENCE.I`, which the core executes as a no-op ([leaf#8](https://github.com/daniel-santos-7/leaf/issues/8)). Code that copies itself and runs belongs in RAM1, which is flip-flops; making RAM0 itself safe is [#8](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/8).

### System Controller
`wb_syscon` generates the SoC reset from the `rst_n` pin, which is active low. It passes the clock through unchanged; the clock tree is left to the physical design flow. The reset goes through a two-flip-flop synchroniser that asserts asynchronously and deasserts synchronously:

- **Assertion:** while `rst_n = '0'` both flip-flops are set, so `rst_o` is high from power-up and from the moment the pin goes low, with or without a clock. Asserting out of step with the clock is safe: a register that misses the first edge sees `rst_o` at the next one, and the state being lost would be discarded anyway.
- **Deassertion:** once the pin is released, a `'0'` shifts through the two stages, so `rst_o` falls two edges later and always right after a clock edge, and every register leaves reset on the same cycle. If the release violates the first stage's recovery time, that stage may go metastable, but the second still holds `'1'` and the first has a whole cycle to settle before it is sampled.

Every other register in the SoC and in the IPs resets synchronously, so it only takes its reset value once the clock runs with `rst_o` high; the board must supply the clock while reset is held. Since the assertion is asynchronous, any pulse on the pin resets the chip, so the pin must be filtered in the pad or on the board.

### SPI Pins
XIP and the debug bridge share one set of four SPI pins, with the SoC as master for XIP and as slave for debug. `spi_port` (`soc_spi`), from the [`ips/spi`](ips/spi/) IP, holds `spi_master`, `spi_slave` and the pin logic, and the input `dbg` picks the role:

| `dbg` | Role | SCK, `CS#`, MOSI | MISO |
|-----------|------|------------------|------|
| 0 | master (XIP) | driven by the SoC | input from the flash |
| 1 | slave (debug) | inputs from the debug host | driven by the SoC while `CS#` is low, released otherwise |

There is no tri-state inside the SoC: each pin leaves `leaf_soc` as `_i`, `_o` and `_oe` (`sclk_*`, `cs_n_*`, `mosi_*`, `miso_*`), as the GPIO does, and the pads or the board resolve them. `dbg` goes through a two-flip-flop synchroniser and is a strap, not a run-time switch: change it only while no XIP read is in progress, e.g. with the CPU running from RAM or halted. While it is 1 the master's request input is gated off and `wb_xip_ctrl` answers every fetch with `ERR` one cycle later, so a jump into XIP takes an access fault instead of hanging; the slave sees `CS#` as high while it is 0, so XIP traffic never reaches the debug bridge.

`CS#` is shared too, so in debug mode the flash sees the host's frames: the board must disconnect the flash (its `CS#` or the whole flash) while `dbg` is 1, or the flash will decode debug commands and fight the SoC on MISO. The testbench does the same: it holds the flash model's `CS#` high and resolves each pin from the `_oe` outputs, and the `DBG=1` check sets `dbg` around the debug frames while the CPU runs from RAM.

### Debug Bridge
The debug bridge is an SPI slave on the same four pins as XIP (see SPI Pins) that turns SPI frames into Wishbone transfers on the data channel. It needs nothing from the core: it can read and write every slave the data master reaches (UART, IO1, GPIO, RAM0 and RAM1 through port A) while a program runs, and it can hold the CPU in reset to load a program. It cannot see the CPU's registers or PC, nor set breakpoints, since the core has no debug port.

It is two modules: `spi_slave`, from the [`ips/spi`](ips/spi/) IP (inside `spi_port`, on the same `SPI_WIDTH` (64-bit) shift core as the XIP master; both roles use the one width, so the debug word costs no extra registers), and `wb_dbg_ctrl` (`soc_dbg_ctrl`). `spi_slave` handles the pins and frames: it carries one 64-bit word each way per `CS#` low. When `CS#` rises it hands the received word to `wb_dbg_ctrl` with the number of bits that arrived (`rx_bits`), and when `CS#` falls it loads the word `wb_dbg_ctrl` keeps on `tx_data` and shifts it out MSB first. `wb_dbg_ctrl` decodes the frame, holds `HALT`, the status and the reply, and is the Wishbone master. Every frame is a whole command, so there is no state between frames, no byte counting and no deadline inside a frame: a command runs after its frame ends, and its result goes out in the next frame.

**SPI:** mode 0 (SCK idle low, MOSI sampled on the rising edge, MISO changes on the falling edge), MSB first, one 64-bit frame per `CS#` low. SCK, `CS#` and MOSI are oversampled by the system clock through two-flip-flop synchronisers, so there is no second clock domain; the price is that SCK must stay at least 5 system cycles high and 5 low (SCK ≤ clk/10, 10 MHz at 100 MHz), and the host must leave at least 5 system cycles between `CS#` falling and the first SCK rise. Bits past the 64th are ignored, so a longer frame counts as its first 64 bits. A shorter frame, including a `CS#` pulse with no SCK edge, is ignored.

A frame is a command word (bits 63–32) followed by a data word (bits 31–0). Transfers are whole words, so the two low address bits are free and carry the operation:

| Command word | Op | Data word | Action when the frame ends |
|--------------|----|-----------|----------------------------|
| `addr[31:2]` & `00` | READ | — | word read at `addr`; the reply carries the data (0 on `ERR`) |
| `addr[31:2]` & `01` | WRITE | data | word write at `addr` |
| `x` & `H` & `10` | CTRL | — | `HALT` = bit 2 (`H`) |
| `x` & `0` & `11` | NOP | — | nothing; fetches the reply |
| `x` & `1` & `11` | ID | — | the reply carries `0x4C454146` (`DBG_ID` in `leaf_soc_pkg`) |

The bus address, write data and `WE` are registered when the transfer starts, like `CYC` and `STB`, so every Wishbone output of the bridge comes straight from a flip-flop and a new frame cannot disturb a transfer still in progress. `WE` drops again when the transfer ends.

The reply is 64 bits: the result word (bits 63–32), a register that READ and ID overwrite and the other commands leave alone, and the status word (bits 31–0), taken live when `CS#` falls. Every frame shifts out the reply as it is when its `CS#` falls, so reading is pipelined: the frame after a READ or ID carries the answer while the host already sends the next command, the way JTAG/SWD debug ports work, and NOP is the filler when there is nothing else to send. A read with its status is two frames: READ `addr`, then any command (the reply has the data and the status). Every reply carries the status, so there is no separate status command.

Status word: bit 0 `HALT`, bit 1 `ERR` (the last transfer ended with `ERR`, e.g. an unmapped address or the ROM, which the data channel does not reach), bit 2 `BUSY` (a transfer is in progress), bit 3 `OVR` (a READ or WRITE arrived while `BUSY`, and was dropped). `OVR` clears itself at the end of the next frame, the one that reported it. `SEL` is always `1111`, so a byte or halfword register has to be updated by read-modify-write. The transfer starts about 3 cycles after `CS#` rises (synchroniser plus edge detection) and takes a few more, and the slave loads the reply about 3 cycles after `CS#` falls, so a host that keeps `CS#` high for one SCK period (10 cycles at the maximum SCK) gets the READ data in the very next frame. `BUSY` and `OVR` only show up if the host ignores that, or if the CPU holds the data channel unusually long.

**Arbitration:** `wb_arbiter` merges the CPU data master (`m0`) and the bridge (`m1`) into the data `wb_channel`. The grant is combinational and held while the owner's `CYC` is high; when the bus is free and both raise `CYC` in the same cycle the bridge wins, which cannot starve the CPU because the bridge issues at most one transfer per SPI frame. The master without the grant sees `STALL` and keeps its request pending (the core's `dmls_block` waits in `REQUEST` on `STALL`). `ACK` and `ERR` go only to the owner. The bridge only looks for its `ACK` from the cycle after its strobe was accepted, so a late response to a CPU request cut short by `HALT` cannot be taken for its own.

**HALT:** OR-ed into the CPU's reset (`soc_cpu_rst`). In COP mode that also resets the pulse generator inside `leaf_qpe`; the peripherals, the RAMs, the bus and the bridge itself keep running, and so does the UART's transmit FIFO, which drains what the program had queued. `HALT` resets to 0. To load a program: `HALT = 1`, WRITE the image into RAM0, `HALT = 0`; the boot ROM then runs and waits for `RAM_JUMP_CMD` (`0x4A`) on the UART, as after a power-up.

The testbench checks the bridge with `DBG=1`: after the program starts it reads the ID, writes and reads back a RAM1 word while the CPU is printing, checks that a short frame and an empty one (`CS#` with no SCK) are ignored, reads the ROM and expects `ERR`, halts, reads RAM0, releases and sends `RAM_JUMP_CMD` again, so the program's output appears twice; the run ends with `DBG ok`:

```bash
make run PROGRAM=sw/c/hello_world/hello_world.bin DBG=1 RUN_CYCLES=300000
```

## :zap: Pulse Generator (QPE)

The waveform generator can be reached through two mutually exclusive interfaces, selected at elaboration time by the `WGEN_IF_COP` generic of `leaf_soc`, which picks between two `generate` blocks. The testbench passes it through, and the Makefile sets it from the `WGEN_IF` variable (`-gWGEN_IF_COP=false` for `MMIO`) when the simulation starts, so both modes are built into the same executable and switching recompiles nothing.

- **`COP` (default):** `leaf_qpe` replaces the plain core, instantiating `leaf` + `qpe_csrs` + `sig_gen`. Pulse parameters live in the CPU's custom CSR window `0x7C0`–`0x7FF`, so a trigger costs no bus transaction. Nothing is attached to IO1, which answers every access with `ERR`, so a stray MMIO access traps instead of hanging.
- **`MMIO`:** the plain core plus `wb_sig_gen` hung off IO1 as an ordinary Wishbone peripheral.

Seven parameters, in the same order in both modes — CSR `0x7C0 + n` in COP, word `IO1_BASE + 4n` in MMIO:

| n | Register | Meaning |
|---|----------|---------|
| 0 | FTW   | Frequency tuning word (32-bit phase increment) |
| 1 | POW   | Phase offset word (32-bit) |
| 2 | AMP   | Amplitude scalar (16-bit unsigned) |
| 3 | DRAG  | Pre-scaled DRAG term, Q1.15 — **not** the coefficient β |
| 4 | ENV   | Envelope step (32-bit); sets the pulse width |
| 5 | DELAY | Inter-pulse delay in clock cycles (24-bit) |
| 6 | TRIG  | Write bit 0 to fire; read for ready/valid status |

QPE, the pulse generator as software sees it, has one API per interface, because the two work differently: `sw/c/common/qpe.c`/`qpe.h` (`qpe_*`) for COP and `sw/c/common/qpe_mmio.c`/`qpe_mmio.h` (`qpe_mmio_*`) for MMIO. A program names the one it needs in its Makefile, so the source says which SoC it targets. Both offer `*_set_*` setters, `*_trigger`, `*_wait_ready`, `*_init` and `*_pulse` with a parameter struct. Only `qpe_mmio` has getters (`qpe_mmio_get_*`), since a COP parameter CSR reads back the pointer, not the value. `rabi`, `ramsey`, `t1` and `wgen_demo` use `qpe`; `wgen_demo_mmio` is `wgen_demo` on `qpe_mmio` and emits the same I/Q samples. Assembly has the same split: `sw/asm/common/qpe.inc` (`qpe.*`, symbols `QPE_CSR_*`) and `sw/asm/common/qpe_mmio.inc` (`qpe_mmio.*`, symbols `QPE_MMIO_*`). A `qpe_mmio.*` setter takes the register holding the *value* and stores it with `sw`, using `t6` for the base; `qpe_mmio.trigger` and `qpe_mmio.wait` also use `t0`. `sw/asm/xwg-test-mmio` is `xwg-test` on `qpe_mmio.*` and emits the same samples. In the RTL, `qpe` names only the COP path (`leaf_qpe`, `qpe_csrs`); the MMIO path is `wb_sig_gen`.

A program only works on a SoC built for the same interface. An MMIO program on a COP SoC traps on its first IO1 access, since nothing answers there but `ERR`. A COP program on an MMIO SoC raises no fault at all: the core forwards the CSR window whether or not a coprocessor is attached, and the MMIO SoC ties that port off, so parameter writes vanish, every read returns 0 and a wait on `TRIG` never ends. `qpe_init()` catches this: it reads `TRIG`, whose bit 1 (ready) is 1 whenever the generator is idle and 0 when nothing answers the CSR window; when it is 0 it prints `QPE: no coprocessor, is this an MMIO SoC?` and stops. `qpe_mmio_init()` does the same check on IO1 and prints `QPE MMIO: no pulse generator on IO1, is this a COP SoC?`, although on a COP SoC that access traps first. The pulse programs call it first, while the generator is still idle. A write followed by a read-back cannot serve as the probe: the core forwards a CSR write to a `csrr` of the same address in the very next instruction, so the read returns the written value even with no coprocessor attached ([leaf#7](https://github.com/daniel-santos-7/leaf/issues/7)).

**DAC port:** `leaf_soc` has a 10-bit input `dac_dat` (`OUT_RES_BITS` wide) and a select input `dac_sel`. While `dac_sel` is 1, `sig_i` and `sig_q` both carry `dac_dat`; while it is 0 they carry the pulse generator's samples. The choice is up to whoever drives the pin: it does not follow `active`, which is not muxed and keeps reporting the generator, so a pulse fired while `dac_sel` is 1 plays internally but does not reach the pins. The mux is combinational and neither input is synchronised, so a change reaches the pins in the same cycle; a board that needs clean values must hold them stable or register them outside. The testbench drives `dac_dat` with `0x123`, and once the program has started it sets `dac_sel`, checks `0x123` on both pins, clears it and checks the idle generator's 0.

The I/Q output width is **not** fixed by the SoC: it follows `OUT_RES_BITS` in the generated `ips/wgen/rtl/sine_lut_pkg.vhd` (currently 10 bits), which `leaf_soc_pkg.vhdl` derives its own constant from. Do not hardcode it in the package, or the SoC ports stop matching `sig_gen`'s.

> **Note — the COP registers hold pointers, not values.** Writing a parameter CSR stores `wdata[4:0]` as a *GPR index*; `qpe_csrs` then snoops the register-file write port and mirrors whatever lands in that GPR from then on. Binding does not copy the register's current value, so bind first, then load the register. The `qpe.*` macros in `sw/asm/common/qpe.inc` take the register *number* and bind with `csrwi`, which needs no scratch register:
>
> ```asm
> qpe.amp 22            # AMP now tracks x22
> li  x22, 0x0000FFFF  # picked up through the register-file snoop
> ```
>
> The assembly examples bind every parameter once at the start and then only write the registers; a sweep is just an `addi` on the bound register. A bound register must not be reused for anything else until the pulse it feeds has launched: `sig_gen` latches the parameters when a trigger is accepted, not when it is written, so a queued `TRIG` launches with whatever the registers hold at that moment.
>
> The pointer scheme avoids giving the register file extra read ports for the pulse parameters: each one costs a full 32-way read mux, and they synthesised poorly. `x0` is never mirrored, since the register file discards writes to it, so a parameter bound to `x0` keeps its last value (0 after reset).
>
> C cannot keep a GPR to itself, since the compiler reuses every register. The `qpe_set_*` setters therefore bind, fill and release: `csrwi <reg>, 5` binds the parameter to `t0`, `mv t0, <value>` loads it, and `csrwi <reg>, 0` binds it back to `x0`, which freezes the mirror at that value. This is safe because the core writes CSRs and the register file in the same stage, in program order. Reading a parameter CSR returns the pointer, so `qpe` has no getters.
>
> A `TRIG` write reaches `sig_gen` combinationally: when the generator is idle (`ready` high) the pulse starts in the same cycle and nothing is stored. When it is busy, `qpe_csrs` latches the request in `valid_reg` until `ready` rises.

## :file_folder: Project Structure

The repository is organized into the following main directories:

- [`ips/`](ips/): Intellectual Property blocks (Git submodules, each with its own Makefile and tests).
  - [`cpu/`](ips/cpu/): The Leaf RISC-V processor core.
  - [`uart/`](ips/uart/): UART controller with Wishbone interface.
  - [`wgen/`](ips/wgen/): DDS-based signal generator.
  - [`gpio/`](ips/gpio/): GPIO with Wishbone interface.
  - [`spi/`](ips/spi/): Dual-role SPI (master and slave on shared pins).
- [`soc/`](soc/): SoC-level RTL implementation and top-level testbenches.
- [`sw/`](sw/): RISC-V software, including bootloaders, libraries, and C/Assembly examples.
- [`waves/`](waves/): Output directory for simulation waveforms (generated at runtime).

Changes under `ips/` belong to the submodule repositories, not to this one.

Instances are written as `entity work.<name>`, so each interface is declared only once, in its entity. `leaf_soc_pkg` keeps component declarations only where a binding has to stay open: `wb_ram_dp`, which the testbench configurations rebind for `soc_ram0`, `leaf_soc`, the instance they descend through, and `sram_dp`, whose architecture a configuration picks per macro (see Macro-based RAM). A hard macro or a Verilog cell instantiated from VHDL also needs a component, since it has no VHDL entity to name.

## :test_tube: Simulation

The SoC can be fully simulated using the provided Makefiles and open-source VHDL tools. The whole design analyses as **VHDL-93**.

### Dependencies
To build and simulate the project, ensure the following tools are installed:

- **GHDL:** VHDL simulator for logic verification.
- **RISC-V Toolchain:** `riscv32-unknown-elf-gcc` (must support `-march=rv32i -mabi=ilp32`).
- **GNU Make:** Used to orchestrate the build and simulation process.
- **Spike:** (Optional) Required only by the CPU differential test suite in `ips/cpu/verif/tests`.
- **GTKWave:** (Optional) Recommended for viewing `.ghw` waveform files.

### Running a Simulation

1. **Initialize Submodules:**
   ```bash
   git submodule update --init --recursive
   ```

2. **Build the Software:**
   ```bash
   make -C sw/c/hello_world
   ```

3. **Execute Simulation:**
   ```bash
   make run PROGRAM=sw/c/hello_world/hello_world.bin
   ```

   The program's UART TX is decoded to stdout, so `printf`/`uart_puts` is the primary debugging channel.

4. **View Waveforms:**
   ```bash
   make run PROGRAM=sw/c/hello_world/hello_world.bin WAVEFORM=ghw
   gtkwave waves/hello_world.ghw
   ```

### Makefile Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PROGRAM` | `sw/asm/hello-world/hello-world.bin` | `.bin` to run; also names the waveform and CSV outputs |
| `RUN_CYCLES` | `500000` | Simulated cycles after load; CoreMark needs tens of millions |
| `WGEN_IF` | `COP` | `COP` or `MMIO` — see the Pulse Generator section |
| `RAM` | `BEHAV` | `BEHAV`, `MACRO` or `TECH` — see Macro-based RAM |
| `TECH_DIR` | `tech` | Directory with the technology sources for `RAM=TECH` |
| `WAVEFORM` | *(none)* | `ghw` or `fst`; written to `waves/<program>.<ext>` |
| `SAMPLES` | *(none)* | `1` dumps every active I/Q sample to `waves/<program>.csv` as `cycle,sig_i,sig_q` |
| `DBG` | *(none)* | `1` runs the SPI debug bridge check after the program starts — see Debug Bridge |

`make clean` runs `ghdl clean` and drops `work/` and `waves/`. The build globs the RTL directories and records the import in a stamp file, so *adding* a source is picked up automatically — but *renaming or deleting* one leaves a stale unit behind and needs a `make clean`.

### Other Targets

```bash
make -C ips/cpu/verif/tests compare                       # CPU differential suite (needs Spike)
make -C ips/wgen run                                      # pulse generator IP testbench
make -C sw run-quick                                      # build CoreMark + simulate, log to sw/logs/
make -C sw upload BIN=./c/hello_world/hello_world.bin PORT=/dev/ttyUSB0
```

`make rtl-tar` packs the synthesisable sources of the SoC into `dist/leaf_soc_rtl.tar`: every file under `soc/rtl` and the IPs' `rtl` directories, with no testbenches and nothing from `TECH_DIR`. The archive is flat: it holds only the files, with no directories, and the build fails if two sources share a file name. Next to them it writes `files.f`, the files in analysis order. GHDL derives that order from the `RTL_TOP` elaboration (default `leaf_soc`), and appends the files that are outside that closure, `sram_dp` and `wb_ram_dp_macro`. The target analyses the list once in a scratch library before packing, so an order that does not analyse fails the build instead of producing the tar. The sources are VHDL-93 and need no `--ieee=synopsys`:

```bash
make rtl-tar
mkdir rtl && tar -xf dist/leaf_soc_rtl.tar -C rtl && cd rtl
ghdl -a $(cat files.f) && ghdl --synth --out=none leaf_soc
```

That archive synthesises RAM0 as the inferred array. `make rtl-tar RAM=TECH` builds `dist/leaf_soc_tech_rtl.tar` for the macro RAM instead: it adds the technology's synthesis sources, which `TECH_DIR` lists in a file `syn.f` (names relative to `TECH_DIR`, no simulation models), and takes its order from the configuration `leaf_soc_tech`, which that directory must provide and which is the unit to synthesise. The macro cell itself stays unbound, a black box whose views come from the memory compiler, so GHDL's "not bound" warning on it is expected. This archive carries the technology files and follows their licence terms, not this repository's. `RAM=MACRO` is refused, since `sram_dp(sim)` is not synthesisable.

## :balance_scale: License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for the full text.

---

<p align="center">2026</p>
