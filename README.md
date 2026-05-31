# :leaves: Leaf

Leaf is an SoC (*System-on-Chip*) ecosystem based on a 32-bit RISC-V processor, designed to be compact, efficient, and ideal for applications in embedded systems and IoT (Internet of Things).

## :star: Features

The Leaf core has the following characteristics:

- **RISC-V ISA (RV32I):** Full support for the base integer instruction set.
- **2-Stage Pipeline:** Optimized for a balance between area and frequency (Fetch / Execute).
- **Wishbone B4 Interface:** Master interface compatible with the Wishbone standard for easy peripheral integration.
- **CSR Support (Machine Mode):** Implementation of control and status registers (`mtvec`, `mepc`, `mcause`, `mstatus`, `mie`, `mip`, `mscratch`, `mtval`) and counters (`mcycle`, `minstret`, `mtime`).
- **Interrupt Handling:** Support for external, software, and timer interrupts.
- **Coprocessor Interface:** Customized CSR window (0x7C0-0x7FF) for hardware expansion.

## :file_folder: Project Structure

The repository is organized as follows:

Directory             | Description
--------------------- | ---------------------------------------------------------
[`ips/cpu/`](ips/cpu/) | Leaf processor core (Submodule)
[`ips/uart/`](ips/uart/) | UART peripheral with Wishbone Slave interface (Submodule)
[`ips/wgen/`](ips/wgen/) | DDS-based sine wave generator (Submodule)
[`soc/`](soc/)         | RTL and testbenches for the full SoC (FPGA-synthesizable)
[`sw/`](sw/)           | Test programs and libraries (C and Assembly)

## :rocket: Getting Started

### Prerequisites

To simulate and develop for Leaf, you will need:

- **GHDL:** Open-source VHDL simulator.
- **RISC-V Toolchain:** `riscv32-unknown-elf-gcc` (configured for `rv32i`).
- **GNU Make:** Build automation.
- **GTKWave:** Waveform viewer (optional).

### Initial Setup

As the IPs are managed via Git submodules, initialize them after cloning the repository:

```bash
git submodule update --init --recursive
```

### SoC Simulation

The project includes a root Makefile to facilitate full system simulation.

1. **Compile a program (C example):**
   ```bash
   make -C sw/c/hello_world
   ```

2. **Run the simulation:**
   ```bash
   make run PROGRAM=sw/c/hello_world/hello_world.bin
   ```

Waveforms will be generated in the `waves/` directory and can be viewed with GTKWave:
```bash
gtkwave waves/hello_world.ghw
```

## :computer: Development Environment

On Linux-based systems (Debian/Ubuntu), you can install the simulation tools with:

```bash
sudo apt install ghdl gtkwave make
```

---

<p align="center">2026</p>
