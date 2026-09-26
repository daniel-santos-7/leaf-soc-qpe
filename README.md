# :leaves: Leaf SoC

Leaf SoC is a compact and efficient 32-bit *System-on-Chip* based on the RISC-V architecture. It is designed for embedded applications, IoT (Internet of Things), and academic research, providing a balanced platform between resource economy and functional completeness.

This repository carries the SoC together with a **QPE** (Quantum Pulse Extension): the CPU drives a DDS waveform generator that emits Gaussian, DRAG-corrected I/Q pulses for qubit control.

## :star: Features

- **Leaf Processor:** 32-bit RISC-V core (RV32I) with a 2-stage pipeline.
- **Wishbone B4 Bus:** Crossbar interconnect; instruction fetch and data accesses run in parallel.
- **Memory System:** Integrated Boot ROM, two internal dual-port RAMs: RAM0 (32 KB) and RAM1 (1 KB).
- **Standard Peripherals:** Includes a robust UART for serial communication.
- **Pulse Generator:** DDS signal generator with Gaussian envelopes and DRAG correction, reachable either as a coprocessor or as a memory-mapped peripheral.
- **Expandability:** Ready for XIP (Execute-In-Place) and custom hardware via a dedicated coprocessor interface.
- **FPGA Friendly:** Synthesizable VHDL design optimized for modern FPGA architectures.

## :gears: Microarchitecture

The SoC architecture is centered around the **Wishbone B4** interconnect, which manages the communication between the Leaf core's two masters and the slave peripherals.

### Processor
The **Leaf** core implements the RV32I base integer instruction set. It features a 2-stage pipeline (Fetch and Execute) and supports Machine-mode CSRs, hardware counters, and interrupts.

### Bus & Interconnect
The Leaf core is Harvard: it has two Wishbone B4 masters, one for instruction fetch and one for data. Both drive the bus as **pipelined** masters: `STB` is asserted for a single cycle and `ACK` is awaited with `CYC` held. Byte selects (`SEL`) and error reporting (`ERR`) are supported.

A single **Intercon** (`wb_intercon`) connects both masters to the slaves as a partial crossbar:

| Master | ROM | XIP | RAM0 B | RAM1 B | UART | IO1 | RAM0 A | RAM1 A |
|--------|:---:|:---:|:------:|:------:|:----:|:---:|:------:|:------:|
| Instruction | ✓ | ✓ | ✓ | ✓ | | | | |
| Data | | | | | ✓ | ✓ | ✓ | ✓ |

The two sets of slaves are disjoint, so there is no arbitration and both channels run in parallel. Each dual-port RAM appears as two slave interfaces, which is what lets a fetch and a load/store complete in the same cycle. Both are instances of the same `wb_ram_dp`: RAM0 with `BITS => 15`, RAM1 with `BITS => 10`.

`wb_intercon` is structural: one **`wb_channel`** per master, i.e. per CPU channel. `wb_channel` has a port group for every slave in the memory map (`rom_*`, `io0_*`, `io1_*`, `xip_*`, `ram0_*`, `ram1_*`) and decodes them against the bases and widths in `leaf_soc_pkg`. The regions are disjoint, which keeps the select one-hot. Each instance connects the slaves routed to its master and ties off the others: their outputs are left `open`, and their inputs are tied to `ACK = '0'`, `ERR = '1'` and zero data.

Inside `wb_channel`:

- **Forward path:** combinational. A slave's `STB` is the master's `STB` gated by the decode of the current address.
- **Response path:** `ACK`, `ERR` and read data are steered by a *registered* select, captured in the request cycle. That way a pipelined master that moves to a new address every cycle still gets each response matched to the request that produced it. The select is only captured while `CYC and STB` is high; otherwise a stale select would survive into idle cycles and could let a phantom `ACK` through.
- **Unrouted accesses:** a tied-off slave answers through its fixed `ERR = '1'`, gated by the registered select like any response, and an address outside the map is answered by the decoder itself. Either way `ERR` arrives one cycle after the request (a load from ROM, a fetch from the UART, an unmapped address), and the CPU takes an access-fault trap instead of waiting for an `ACK` that never comes. A slave with no error signal of its own, when routed, has its `ERR` input tied to `'0'`.
- **Stall:** each channel drives its master's `STALL`. It is high while an XIP transfer is outstanding: `xip_sel_reg` is set when the XIP request is accepted and held until the XIP `ACK`, and while it is high the channel gates its own `req` and every slave's `STB`, so the master keeps its next request pending and nothing can overtake the slow response. Everywhere else it stays `'0'`: no other slave inserts wait states, and `wb_sig_gen`'s `stall_o`, tied low, is left open.

The response path assumes every slave acknowledges exactly one cycle after its strobe. This holds for the ROM, the ports of both RAMs and the UART. XIP is the exception, and the stall above is what makes it work: its select is held instead of being recaptured every cycle, so there is only ever one XIP request in flight and its `ACK` is matched to it no matter how late it comes.

### XIP Controller
`wb_xip_ctrl` turns each instruction fetch in `0x20000000`–`0x20FFFFFF` into one SPI Read (`0x03`) of four bytes: command, 24-bit address, 32 data bits, 64 SCK periods in all. It uses SPI mode 0 with SCK at half the system clock: `CS#` falls together with the first MOSI bit, MOSI changes on SCK falling edges, and MISO is sampled in the system cycle in which SCK rises, a full cycle after the flash drove it. `spi_clk`, `spi_mosi` and `spi_cs_n` all come straight from flip-flops. A word takes 130 cycles (128 with `CS#` low), and the instruction master is stalled for all of it, so code in XIP runs roughly two orders of magnitude slower than from RAM.

XIP is fetch-only. The controller has no write path and no `ERR`, and the data channel keeps XIP tied off, so a load or store there takes an access fault. In simulation the testbench's `spi_flash_model` holds a copy of the program binary (512 KB, addresses wrap), so a function at `0x80000000 + n` can also be called at `0x20000000 + n` if its code is position-independent. `sw/c/xip_test` does exactly that and compares the result with the RAM0 call (`XIP ram=0efff9dc xip=0efff9dc ok`).

Routing a slave to a master means connecting its port group on that master's `wb_channel` instead of tying it off. A new slave in the memory map needs a port group in `wb_channel`. A slave reachable from both masters also needs an arbiter in front of it.

### Memory Map
The default address space allocation is defined as follows:

| Peripheral | Base Address | Size | Description |
|------------|--------------|------|-------------|
| **ROM**    | `0x00001000` | 512 B | Bootloader / Initialization code |
| **UART**   | `0x10000000` | 16 B | Serial communication (IO0) |
| **IO1**    | `0x10001000` | 32 B | Pulse generator CSRs (MMIO mode only) |
| **XIP**    | `0x20000000` | 16 MB | External Flash / Execute-In-Place (Optional) |
| **RAM0**   | `0x80000000` | 32 KB | Main System Memory (dual-port: A = data, B = instruction) |
| **RAM1**   | `0x90000000` | 1 KB | Secondary memory (dual-port: A = data, B = instruction) |

Bases and widths are declared once in [`soc/rtl/leaf_soc_pkg.vhdl`](soc/rtl/leaf_soc_pkg.vhdl), which is the source of truth for the map.

Programs are linked into RAM0 (`sw/*/common/soc.ld`). RAM1 is declared there as a second region with a `.ram1` section, which is `NOLOAD`: a loadable section at `0x90000000` would make `objcopy -O binary` pad the `.bin` across the 256 MB gap from RAM0. So RAM1 is never preloaded and `crt0` does not clear it, and its contents are undefined until the program writes them. Put data there with `__attribute__((section(".ram1")))`. Code must be copied in at run time, and the instruction master can then fetch it. `sw/c/ram1_test` sweeps the whole region with word, half-word and byte accesses, prints a checksum (`d2072fde`) and an error count, then copies two instructions in and calls them (`exec=42`). In simulation `soc_ram1` binds to the synthesis `wb_ram_dp`, not a preloading model.

### System Controller
The **Syscon** module handles global clock buffering and synchronized reset generation for the entire SoC.

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

`sw/c/common/wgen.c` abstracts over both interfaces and compiles to CSR or MMIO accesses under `WGEN_IF_MMIO`. No Makefile defines that macro, so C builds target the COP path unless you add `-DWGEN_IF_MMIO`.

The I/Q output width is **not** fixed by the SoC: it follows `OUT_RES_BITS` in the generated `ips/wgen/rtl/sine_lut_pkg.vhd` (currently 10 bits), which `leaf_soc_pkg.vhdl` derives its own constant from.

> **Note — the COP registers hold pointers, not values.** Writing a parameter CSR stores `wdata[4:0]` as a *GPR index*; `qpe_csrs` then snoops the register-file write port and mirrors whatever lands in that GPR. Bind first, then load the register:
>
> ```asm
> li  t0, 22
> qp.amp t0            # AMP now tracks x22
> li  x22, 0x0000FFFF  # picked up through the register-file snoop
> ```
>
> The assembly examples under `sw/asm/` predate this convention and load literal values into the pointed registers, so they bind to arbitrary GPRs and emit an all-zero pulse. The MMIO path stores values directly and is unaffected.

## :file_folder: Project Structure

The repository is organized into the following main directories:

- [`ips/`](ips/): Intellectual Property blocks (Git submodules, each with its own Makefile and tests).
  - [`cpu/`](ips/cpu/): The Leaf RISC-V processor core.
  - [`uart/`](ips/uart/): UART controller with Wishbone interface.
  - [`wgen/`](ips/wgen/): DDS-based signal generator.
- [`soc/`](soc/): SoC-level RTL implementation and top-level testbenches.
- [`sw/`](sw/): RISC-V software, including bootloaders, libraries, and C/Assembly examples.
- [`waves/`](waves/): Output directory for simulation waveforms (generated at runtime).

Changes under `ips/` belong to the submodule repositories, not to this one.

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
| `WAVEFORM` | *(none)* | `ghw` or `fst`; written to `waves/<program>.<ext>` |
| `SAMPLES` | *(none)* | `1` dumps every active I/Q sample to `waves/<program>.csv` as `cycle,sig_i,sig_q` |

`make clean` runs `ghdl clean` and drops `work/` and `waves/`. The build globs the RTL directories and records the import in a stamp file, so *adding* a source is picked up automatically — but *renaming or deleting* one leaves a stale unit behind and needs a `make clean`.

### Other Targets

```bash
make -C ips/cpu/verif/tests compare                       # CPU differential suite (needs Spike)
make -C ips/wgen run                                      # pulse generator IP testbench
make -C sw run-quick                                      # build CoreMark + simulate, log to sw/logs/
make -C sw upload BIN=./c/hello_world/hello_world.bin PORT=/dev/ttyUSB0
```

## :balance_scale: License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for the full text.

---

<p align="center">2026</p>
