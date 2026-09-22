# :leaves: Leaf SoC

Leaf SoC is a compact and efficient 32-bit *System-on-Chip* based on the RISC-V architecture. It is designed for embedded applications, IoT (Internet of Things), and academic research, providing a balanced platform between resource economy and functional completeness.

This repository carries the SoC together with a **QPE** (Quantum Pulse Extension): the CPU drives a DDS waveform generator that emits Gaussian, DRAG-corrected I/Q pulses for qubit control.

## :star: Features

- **Leaf Processor:** 32-bit RISC-V core (RV32I) with a 2-stage pipeline.
- **Wishbone B4 Bus:** Shared-bus interconnection for seamless peripheral integration.
- **Memory System:** Integrated Boot ROM and 32 KB of internal dual-port RAM.
- **Standard Peripherals:** Includes a robust UART for serial communication.
- **Pulse Generator:** DDS signal generator with Gaussian envelopes and DRAG correction, reachable either as a coprocessor or as a memory-mapped peripheral.
- **Expandability:** Ready for XIP (Execute-In-Place) and custom hardware via a dedicated coprocessor interface.
- **FPGA Friendly:** Synthesizable VHDL design optimized for modern FPGA architectures.

## :gears: Microarchitecture

The SoC architecture is centered around the **Wishbone B4** interconnect, which manages the communication between the Leaf master and several slave peripherals.

### Processor
The **Leaf** core implements the RV32I base integer instruction set. It features a 2-stage pipeline (Fetch and Execute) and supports Machine-mode CSRs, hardware counters, and interrupts.

### Bus & Interconnect
A central **Intercon** module performs address decoding and bus steering. It uses the Wishbone B4 protocol, supporting byte-selects (`SEL`) and error reporting (`ERR`). The CPU drives the bus as a **pipelined** master: it asserts `STB` for a single cycle and waits for `ACK` with `CYC` held.

### Memory Map
The default address space allocation is defined as follows:

| Peripheral | Base Address | Size | Description |
|------------|--------------|------|-------------|
| **ROM**    | `0x00001000` | 512 B | Bootloader / Initialization code |
| **UART**   | `0x10000000` | 16 B | Serial communication (IO0) |
| **IO1**    | `0x10001000` | 32 B | Pulse generator CSRs (MMIO mode only) |
| **XIP**    | `0x20000000` | 16 MB | External Flash / Execute-In-Place (Optional) |
| **RAM**    | `0x80000000` | 32 KB | Main System Memory (dual-port: A = data, B = instruction) |

Bases and widths are declared once in [`soc/rtl/leaf_soc_pkg.vhdl`](soc/rtl/leaf_soc_pkg.vhdl), which is the source of truth for the map.

### System Controller
The **Syscon** module handles global clock buffering and synchronized reset generation for the entire SoC.

## :zap: Pulse Generator (QPE)

The waveform generator can be reached through two mutually exclusive interfaces, selected at elaboration time by the `WGEN_IF` variable. The Makefile generates `soc/rtl/wgen_cfg.vhdl` from it, and `leaf_soc.vhdl` picks between two `generate` blocks — no source edit is needed to switch.

- **`COP` (default):** `leaf_wgx` replaces the plain core, instantiating `leaf` + `wgx_csrs` + `sig_gen`. Pulse parameters live in the CPU's custom CSR window `0x7C0`–`0x7FF`, so a trigger costs no bus transaction. IO1 is tied off.
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

> **Note — the COP registers hold pointers, not values.** Writing a parameter CSR stores `wdata[4:0]` as a *GPR index*; `wgx_csrs` then snoops the register-file write port and mirrors whatever lands in that GPR. Bind first, then load the register:
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

`make clean` runs `ghdl clean` and drops `work/`, `waves/` and the generated `wgen_cfg.vhdl`. The build globs the RTL directories and records the import in a stamp file, so *adding* a source is picked up automatically — but *renaming or deleting* one leaves a stale unit behind and needs a `make clean`.

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
