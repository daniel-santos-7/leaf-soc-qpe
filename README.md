# :leaves: Leaf SoC

Leaf SoC is a compact and efficient 32-bit *System-on-Chip* based on the RISC-V architecture. It is designed for embedded applications, IoT (Internet of Things), and academic research, providing a balanced platform between resource economy and functional completeness.

This repository carries the SoC together with a **QPE** (Quantum Pulse Extension): the CPU drives a DDS waveform generator that emits Gaussian, DRAG-corrected I/Q pulses for qubit control.

## :star: Features

- **Leaf Processor:** 32-bit RISC-V core (RV32I) with a 2-stage pipeline.
- **Wishbone B4 Bus:** Crossbar interconnect; instruction fetch and data accesses run in parallel.
- **Memory System:** Boot ROM and two dual-port RAMs: RAM0 (1 KB) and RAM1 (32 KB).
- **Standard Peripherals:** UART and an 8-pin GPIO with edge interrupts.
- **Pulse Generator:** DDS signal generator with Gaussian envelopes and DRAG correction, reachable as a coprocessor or as a memory-mapped peripheral.
- **XIP:** Execute-in-place from an external SPI NOR flash.
- **Debug Bridge:** SPI slave that reads and writes the data bus and holds the CPU in reset.
- **FPGA Friendly:** Synthesizable VHDL-93.

## :gears: Microarchitecture

### Processor
The **Leaf** core implements RV32I with a 2-stage pipeline (Fetch and Execute), Machine-mode CSRs, hardware counters and interrupts.

### Bus & Interconnect
The core has two Wishbone B4 masters, one for instruction fetch and one for data; the SPI debug bridge is a third master that shares the data channel. All of them are pipelined masters (`STB` for one cycle, `ACK` awaited with `CYC` held) and use `SEL` and `ERR`.

`wb_intercon` connects them to the slaves as a partial crossbar:

| Master | ROM | XIP B | RAM0 B | RAM1 B | UART | IO1 | GPIO | XIP A | RAM0 A | RAM1 A |
|--------|:---:|:-----:|:------:|:------:|:----:|:---:|:----:|:-----:|:------:|:------:|
| Instruction | ✓ | ✓ | ✓ | ✓ | | | | | | |
| Data | | | | | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Debug (via data) | | | | | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

The two slave sets are disjoint, so the CPU channels run in parallel with no arbitration. Each RAM and the XIP controller have two slave interfaces, B for instruction and A for data, so a fetch and a load/store can complete in the same cycle. The debug bridge enters the data channel through `wb_arbiter` (see Debug Bridge).

`wb_intercon` holds one `wb_channel` per master, which decodes the address against `leaf_soc_pkg`:

- **Responses** are steered by a registered select, held until the addressed slave answers, so there is one transfer in flight per channel and a slave may take any number of cycles. Single-cycle slaves still run at one transfer per cycle.
- **Errors:** an unmapped address, or a slave not routed to that master (a load from ROM, a fetch from the UART), answers `ERR` one cycle later and the CPU takes an access fault.
- **Stall** is raised while a response is outstanding or while the addressed slave raises its own `STALL`. Only the XIP fetch port and RAM1's data port (see Macro-based RAM) ever do.

Every slave accepts a request on every cycle, with no gating on its pending `ACK`. Routing a slave to another master means connecting its port group on that master's `wb_channel`, plus an arbiter once two masters can reach it.

### XIP Controller
`wb_xip_ctrl` turns each instruction fetch in `0x20000000`–`0x20FFFFFF` into one SPI Read (`03h`): command, 24-bit address and 32 data bits in a single 64-bit frame, SPI mode 0, MSB first. The flash sends the lowest address first, so the word is byte-swapped for the little-endian CPU. Frames go out through the master role of the shared SPI port (see SPI Pins), and the instruction master is stalled for the whole read.

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

### Memory Map

| Peripheral | Base Address | Size | Description |
|------------|--------------|------|-------------|
| **ROM**    | `0x00001000` | 512 B | Bootloader |
| **UART**   | `0x10000000` | 16 B | Serial communication (IO0) |
| **IO1**    | `0x10001000` | 32 B | Pulse generator registers (MMIO mode only) |
| **GPIO**   | `0x10002000` | 64 B | General-purpose I/O, 8 pins (IO2) |
| **XIP**    | `0x20000000` | 16 MB | External SPI flash, execute-in-place |
| **RAM0**   | `0x80000000` | 1 KB | Scratch memory, flip-flops |
| **RAM1**   | `0x90000000` | 32 KB | Program memory, SRAM macros |

[`soc/rtl/leaf_soc_pkg.vhdl`](soc/rtl/leaf_soc_pkg.vhdl) is the source of truth for bases and widths.

Both RAMs are optional, through the `leaf_soc` generics `RAM0_EN` (default `true`) and `RAM1_EN` (default `false`). An absent RAM answers every access with `ERR`. The programs in `sw/` are linked into RAM1, so an integration that runs them sets `RAM1_EN => true`; the testbench does.

Programs are linked into RAM1 (`sw/*/common/soc.ld`). RAM0 is a `NOLOAD` section, `.ram0`: it is never preloaded nor cleared by `crt0`. Put data there with `__attribute__((section(".ram0")))`; code must be copied in at run time.

**Boot ROM:** `sw/asm/boot/start.S`, converted into `soc/rtl/boot_pkg.vhdl` by `boot.py`. It takes one command byte at a time on the UART and answers `NAK` to anything else:

| Command | Code | Action |
|---------|------|--------|
| `RAM1_LOAD_CMD` | `0x4C` (`L`) | receive a program into RAM1 |
| `RAM1_JUMP_CMD` | `0x4A` (`J`) | jump to `0x90000000` |
| `RAM0_LOAD_CMD` | `0x6C` (`l`) | receive a program into RAM0 |
| `RAM0_JUMP_CMD` | `0x6A` (`j`) | jump to `0x80000000` |

A load answers `ACK`, then takes the 32-bit size with its CRC-8 and the image in 1 KB blocks, each followed by its CRC-8 and answered with `ACK` or `NAK` (resend). A program for RAM0 must be linked at `0x80000000` and fit, with its stack, in 1 KB.

The boot ROM points `mtvec` at its own handler before anything else. On a trap it prints `!`, `mcause`, `mepc` and `mtval` in hex and goes back to waiting for a command, so the host can see what happened without a reset. A jump to the UART prints:

```
! 00000001 10000000 10000000
```

A program that wants its own handler writes `mtvec`.

### GPIO
The GPIO is the [`wb-gpio`](https://github.com/daniel-santos-7/wb-gpio) IP (submodule `ips/gpio`), 8 pins (`GPIO_WIDTH` in `leaf_soc_pkg`) on IO2, reached by the data master only.

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

The pins leave `leaf_soc` as `gpio_i`, `gpio_o` and `gpio_oe` (1 = drive); the tri-state buffer belongs to the pads or the board. `irq_o` drives the CPU's external interrupt (`mip.MEIP`), the only interrupt source in the SoC. It stays high while any `IRQ_STATUS` bit is set, so a handler must clear the status before returning, and software must install its own `mtvec` handler to take it.

Software: `sw/c/common/gpio.c`/`gpio.h` in C (added through `APP_SRC`) and `sw/asm/common/gpio.inc` in assembly, with one call per register and pin masks as arguments. The assembly macros use `t6` for the base. `sw/c/gpio_test` shows the full flow, interrupt included.

### Macro-based RAM
`wb_ram_dp` has two architectures with the same ports: `rtl` infers the array, and `macro` builds RAM1's 32 KB from eight 2048 × 16 dual-port SRAM macros (four banks by two halves). `rtl` is the default binding, so RAM0, and `leaf_soc` synthesised without a configuration, get the inferred array. RAM0 always uses `rtl`: at 1 KB it is smaller than one macro.

The macros are reached through `sram_dp` (`soc/rtl/sram_dp.vhdl`), a technology-neutral synchronous SRAM interface. `soc/tbs/sram_dp_sim.vhdl` models it for simulation. The technology architecture, which maps it onto a real macro, is not in this repository: it comes from a memory compiler under NDA and lives in `TECH_DIR` (default `tech/`, gitignored), together with the configurations that use it.

`RAM` picks what the testbench binds to RAM1:

| `RAM` | Top | RAM1 |
|-------|-----|------|
| `BEHAV` | `leaf_soc_tb_sim` | inferred array |
| `MACRO` | `leaf_soc_tb_macro` | `wb_ram_dp(macro)` over `sram_dp(sim)` |
| `TECH` | `leaf_soc_tb_tech` | `wb_ram_dp(macro)` over the technology architecture |

For synthesis with macros, use the configuration `leaf_soc_tech` from `TECH_DIR`; it leaves the macro cell unbound, as a black box.

A store on port A and a fetch on port B of the same word in the same cycle would leave the fetch undefined in a macro. `wb_ram_dp(macro)` delays the store by one cycle instead (port A stalls), so the fetch sees the old word under every `RAM`. Code written at run time must be jumped to before it runs; `FENCE.I` is a no-op on this core ([leaf#8](https://github.com/daniel-santos-7/leaf/issues/8)).

`sw/c/ram_test` checks RAM1 end to end and prints `checksum 52E41464`, `errors 00000000` under every `RAM` (about 6M cycles).

### System Controller
`wb_syscon` passes the clock through and generates two resets from the active-low `rst_n` pin:

- **`sys_rst_o`**, the system reset: `rst_n` through a three-flip-flop synchroniser. It asserts asynchronously, with or without a clock, and releases on the third rising edge of `clk` after `rst_n` rises.
- **`cpu_rst_o`**, the CPU reset: the same, and also held while the debug bridge's `HALT` is set. It comes from a flip-flop, so the CPU enters and leaves a halt one cycle after `HALT` changes.

Every other register resets synchronously, so the clock must run while reset is held. Any pulse on `rst_n` resets the chip, so the pin must be filtered in the pad or on the board.

### SPI Pins
XIP and the debug bridge share one set of four SPI pins: the SoC is the master for XIP and a slave for debug. Both roles use one `spi_port` from the [`ips/spi`](ips/spi/) IP, and `spi_mux` connects it to `wb_xip_ctrl` or `wb_dbg_ctrl` according to the role in effect. The `EN` bit of the XIP configuration register picks the role:

| `EN` | Role | SCK, `CS#`, MOSI | MISO |
|------|------|------------------|------|
| 1 | master (XIP) | driven by the SoC | input from the flash |
| 0 | slave (debug) | inputs from the debug host | driven by the SoC while `CS#` is low |

`EN` resets to 0, so after a reset the port belongs to the debug bridge and a host can always reach the SoC. The role changes only between frames. Each pin leaves `leaf_soc` as `_i`, `_o` and `_oe`; there is no tri-state inside the SoC.

`CS#` is shared too, so the board must pass it to the flash only while `cs_n_oe` is 1, and hold the flash deselected otherwise; if not, the flash decodes debug frames and fights the SoC on MISO. The testbench does the same, with a pull-down on MISO.

### Debug Bridge
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

## :zap: Pulse Generator (QPE)

The waveform generator ([`ips/wgen`](ips/wgen/)) is reached through one of two interfaces, chosen by the `leaf_soc` generic `WGEN_IF_COP` (Makefile `WGEN_IF`):

- **`COP` (default):** `leaf_qpe` replaces the plain core and exposes the parameters in the CPU's custom CSR window `0x7C0`–`0x7FF`, so a trigger costs no bus transaction. IO1 answers every access with `ERR`.
- **`MMIO`:** the plain core plus `wb_sig_gen` on IO1 as an ordinary Wishbone peripheral.

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

Software has one API per interface: `sw/c/common/qpe.c`/`qpe.h` and `sw/asm/common/qpe.inc` for COP, `qpe_mmio.c`/`qpe_mmio.h` and `qpe_mmio.inc` for MMIO. A program names the one it needs in its Makefile. `rabi`, `ramsey`, `t1` and `wgen_demo` use `qpe`; `wgen_demo_mmio` and `xwg-test-mmio` are the MMIO versions and emit the same samples.

A program only works on a SoC built for the same interface: an MMIO program on a COP SoC traps on IO1, and a COP program on an MMIO SoC would wait forever. `qpe_init()` and `qpe_mmio_init()` detect the mismatch and print a message instead; the pulse programs call them first.

> **Note — the COP registers hold pointers, not values.** Writing a parameter CSR stores `wdata[4:0]` as a *GPR index*, and `qpe_csrs` mirrors every later write to that GPR by snooping the register-file write port, which saves the register file extra read ports. Bind first, then load the register. The `qpe.*` macros take the register *number*:
>
> ```asm
> qpe.amp 22            # AMP now tracks x22
> li  x22, 0x0000FFFF  # picked up through the register-file snoop
> ```
>
> A bound register must not be reused until the pulse it feeds has launched, since `sig_gen` latches the parameters when the trigger is accepted. In C, the `qpe_set_*` setters bind the parameter to `t0`, load it and bind it back to `x0`, which is never written and so freezes the value. Reading a parameter CSR returns the pointer, so `qpe` has no getters.

**DAC port:** while a pulse is active, `sig_i` and `sig_q` carry its samples; otherwise both carry the `dac_dat` input, which the board must drive (with 0 or its own rest level). A pulse always takes the pins. The outputs come from flip-flops in `dac_out` (one cycle of latency) and read 0 during reset. `dac_dat` is sampled on the rising edge of `clk` with no synchroniser, so the board must meet setup and hold there. `active` stays a `leaf_soc` port for integration and test; it does not go to a pad.

The I/Q width follows `OUT_RES_BITS` in the generated `ips/wgen/rtl/sine_lut_pkg.vhd` (currently 10 bits); do not hardcode it in `leaf_soc_pkg`.

**Sample clock:** `dac_clk` is the system clock inverted, generated in `dac_out`. The samples change just after the rising edge of `clk`, so `dac_clk` rises half a period later, in the middle of the data eye. It assumes a DAC that captures one sample per cycle on the rising edge of a data clock. In an ASIC the pin is a generated clock, with the DAC's setup and hold as output delays:

```tcl
create_generated_clock -name dac_clk -source [get_ports clk] -invert -divide_by 1 [get_ports dac_clk]
set_output_delay -clock dac_clk -max <DAC tSU> [get_ports {sig_i[*] sig_q[*]}]
set_output_delay -clock dac_clk -min -<DAC tH>  [get_ports {sig_i[*] sig_q[*]}]
```

## :file_folder: Project Structure

- [`ips/`](ips/): IP blocks, as Git submodules with their own Makefiles and tests. Changes there belong to the submodule repositories.
  - [`cpu/`](ips/cpu/): the Leaf RISC-V core.
  - [`uart/`](ips/uart/): UART with a Wishbone interface.
  - [`wgen/`](ips/wgen/): DDS signal generator.
  - [`gpio/`](ips/gpio/): GPIO with a Wishbone interface.
  - [`spi/`](ips/spi/): dual-role SPI (master and slave on shared pins).
- [`soc/`](soc/): SoC RTL and testbenches.
- [`sw/`](sw/): bootloader, libraries and C/assembly examples.

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
| `WGEN_IF` | `COP` | `COP` or `MMIO` — see Pulse Generator |
| `RAM` | `BEHAV` | `BEHAV`, `MACRO` or `TECH` — see Macro-based RAM |
| `TECH_DIR` | `tech` | Directory with the technology sources for `RAM=TECH` |
| `WAVEFORM` | *(none)* | `ghw` or `fst`; written to `waves/<program>.<ext>` |
| `SAMPLES` | *(none)* | `1` dumps every active I/Q sample to `waves/<program>.csv` as `cycle,sig_i,sig_q` |
| `DBG` | *(none)* | `1` runs the debug bridge check (with `sw/c/hello_world`, ends with `DBG ok`) |
| `ROLE` | *(none)* | `1` runs the debug → XIP → debug role change check with `sw/c/role_test` (ends with `ROLE ok`) |
| `COLL` | *(none)* | `1` runs the RAM1 store/fetch collision check with `sw/asm/coll-test` |
| `TRAP` | *(none)* | `1` runs the boot ROM trap handler check with `sw/asm/trap-test` (ends with `TRAP ok`) |
| `BOOT_RAM0` | *(none)* | `1` uploads `PROGRAM` over the UART into RAM0 and starts it there, instead of preloading RAM1 (slow) |
| `RAM0` | *(none)* | `0` builds the SoC without RAM0; refused with `BOOT_RAM0`, `DBG`, `ROLE` or `COLL` |
| `RAM1` | *(none)* | `0` builds the SoC without RAM1; needs `BOOT_RAM0=1` |

`make clean` drops `work/` and `waves/`. Adding a source is picked up automatically, but renaming or deleting one needs a `make clean`.

### Other Targets

```bash
make -C ips/cpu/verif/tests compare                       # CPU differential suite (needs Spike)
make -C ips/wgen run                                      # pulse generator IP testbench
make -C sw run-quick                                      # build CoreMark + simulate, log to sw/logs/
make -C sw upload BIN=./c/hello_world/hello_world.bin PORT=/dev/ttyUSB0
make rtl-tar                                              # synthesisable sources in dist/leaf_soc_rtl.tar
make area                                                 # per-module area estimate (needs Yosys with the GHDL plugin)
```

`make rtl-tar` packs the synthesisable sources, flat, with a `files.f` in analysis order:

```bash
mkdir rtl && tar -xf dist/leaf_soc_rtl.tar -C rtl && cd rtl
ghdl -a $(cat files.f) && ghdl --synth --out=none leaf_soc
```

`make rtl-tar RAM=TECH` builds `dist/leaf_soc_tech_rtl.tar` with the technology files listed in `TECH_DIR/syn.f` and the top `leaf_soc_tech`; it follows the technology's licence terms, not this repository's.

`make area` synthesises the SoC with Yosys down to generic gates and reports transistors and flip-flops per module, to compare blocks (not a cell-library area). It takes `WGEN_IF`, `RAM`, `RAM0`, `RAM1` and `AREA_DEPTH` (default 3).

## :balance_scale: License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for the full text.

---

<p align="center">2026</p>
