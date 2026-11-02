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

The **Leaf** core implements RV32I with a 2-stage pipeline (Fetch and Execute), Machine-mode CSRs, hardware counters and interrupts. Its instruction and data masters reach disjoint sets of Wishbone B4 slaves through a partial crossbar, so fetches and loads/stores run in parallel.

| Peripheral | Base Address | Size | Description |
|------------|--------------|------|-------------|
| **ROM**    | `0x00001000` | 512 B | Bootloader |
| **UART**   | `0x10000000` | 16 B | Serial communication (IO0) |
| **IO1**    | `0x10001000` | 32 B | Pulse generator registers (MMIO mode only) |
| **GPIO**   | `0x10002000` | 64 B | General-purpose I/O, 8 pins (IO2) |
| **XIP**    | `0x20000000` | 16 MB | External SPI flash, execute-in-place |
| **RAM0**   | `0x80000000` | 1 KB | Scratch memory, flip-flops |
| **RAM1**   | `0x90000000` | 32 KB | Program memory, SRAM macros |

[`soc/rtl/leaf_soc_pkg.vhdl`](soc/rtl/leaf_soc_pkg.vhdl) is the source of truth for bases and widths. Each block is described in [`docs/`](docs/):

| Document | Contents |
|----------|----------|
| [Bus & Interconnect](docs/bus.md) | Crossbar, responses, errors and stalls |
| [Memory](docs/memory.md) | Memory map, optional RAMs, linking, boot ROM, macro-based RAM |
| [XIP Controller](docs/xip.md) | Execute-in-place from SPI flash, configuration register, timing |
| [GPIO](docs/gpio.md) | Registers, pins and interrupt |
| [System Controller](docs/syscon.md) | Clock and resets |
| [SPI Pins](docs/spi-pins.md) | Pins shared by XIP and the debug bridge, board requirements |
| [Debug Bridge](docs/debug-bridge.md) | SPI frames, commands, reply and `HALT` |
| [SoC IOs](docs/leaf_soc_io.md) | Ports of `leaf_soc` (in Portuguese) |

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
| `RAM` | `BEHAV` | `BEHAV`, `MACRO` or `TECH` — see [Memory](docs/memory.md#macro-based-ram) |
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
