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

## :books: Documentation

| Document | Contents |
|----------|----------|
| [Bus & Interconnect](docs/bus.md) | Crossbar, responses, errors and stalls |
| [Memory](docs/memory.md) | Memory map, optional RAMs, linking, boot ROM, macro-based RAM |
| [XIP Controller](docs/xip.md) | Execute-in-place from SPI flash |
| [GPIO](docs/gpio.md) | Registers, pins and interrupt |
| [System Controller](docs/syscon.md) | Clock and resets |
| [SPI Pins](docs/spi-pins.md) | Pins shared by XIP and the debug bridge |
| [Debug Bridge](docs/debug-bridge.md) | SPI frames, commands, reply and `HALT` |
| [Pulse Generator](docs/qpe.md) | COP and MMIO interfaces, registers, APIs, DAC port |
| [Simulation](docs/simulation.md) | Dependencies, Makefile variables and targets |
| [SoC IOs](docs/leaf_soc_io.md) | Ports of `leaf_soc` (in Portuguese) |

## :file_folder: Project Structure

- [`ips/`](ips/): IP blocks, as Git submodules: [`cpu`](ips/cpu/), [`uart`](ips/uart/), [`wgen`](ips/wgen/), [`gpio`](ips/gpio/), [`spi`](ips/spi/).
- [`soc/`](soc/): SoC RTL and testbenches.
- [`sw/`](sw/): bootloader, libraries and C/assembly examples.
- [`docs/`](docs/): documentation.

## :rocket: Quick Start

Needs GHDL, `riscv32-unknown-elf-gcc` and GNU Make.

```bash
git submodule update --init --recursive
make -C sw/c/hello_world
make run PROGRAM=sw/c/hello_world/hello_world.bin
```

The program's UART output is printed to stdout.

## :balance_scale: License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for the full text.

---

<p align="center">2026</p>
