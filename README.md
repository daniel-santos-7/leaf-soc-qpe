# :leaves: Leaf SoC

Leaf SoC is a compact and efficient 32-bit *System-on-Chip* based on the RISC-V architecture. It is designed for embedded applications, IoT (Internet of Things), and academic research, providing a balanced platform between resource economy and functional completeness.

## :star: Features

- **Leaf Processor:** 32-bit RISC-V core (RV32I) with a 2-stage pipeline.
- **Wishbone B4 Bus:** Shared-bus interconnection for seamless peripheral integration.
- **Memory System:** Integrated Boot ROM and 64 KB of internal RAM.
- **Standard Peripherals:** Includes a robust UART for serial communication.
- **Expandability:** Ready for XIP (Execute-In-Place) and custom hardware via a dedicated coprocessor interface.
- **FPGA Friendly:** Synthesizable VHDL design optimized for modern FPGA architectures.

## :gears: Microarchitecture

The SoC architecture is centered around the **Wishbone B4** interconnect, which manages the communication between the Leaf master and several slave peripherals.

### Processor
The **Leaf** core implements the RV32I base integer instruction set. It features a 2-stage pipeline (Fetch and Execute) and supports Machine-mode CSRs, hardware counters, and interrupts.

### Bus & Interconnect
A central **Intercon** module performs address decoding and bus steering. It uses the Wishbone B4 protocol, supporting byte-selects (`SEL`) and error reporting (`ERR`).

### Memory Map
The default address space allocation is defined as follows:

| Peripheral | Base Address | Size | Description |
|------------|--------------|------|-------------|
| **ROM**    | `0x00001000` | 512 B | Bootloader / Initialization code |
| **UART**   | `10000000` | 16 B | Serial communication (IO0) |
| **IO1**    | `0x10001000` | 16 B | Reserved for secondary IO |
| **XIP**    | `0x20000000` | 16 MB | External Flash / Execute-In-Place (Optional) |
| **RAM**    | `0x80000000` | 64 KB | Main System Memory |

### System Controller
The **Syscon** module handles global clock buffering and synchronized reset generation for the entire SoC.

## :file_folder: Project Structure

The repository is organized into the following main directories:

- [`ips/`](ips/): Intellectual Property blocks (Git submodules).
  - [`cpu/`](ips/cpu/): The Leaf RISC-V processor core.
  - [`uart/`](ips/uart/): UART controller with Wishbone interface.
  - [`wgen/`](ips/wgen/): DDS-based signal generator.
- [`soc/`](soc/): SoC-level RTL implementation and top-level testbenches.
- [`sw/`](sw/): RISC-V software, including bootloaders, libraries, and C/Assembly examples.
- [`waves/`](waves/): Output directory for simulation waveforms (generated at runtime).

## :test_tube: Simulation

The SoC can be fully simulated using the provided Makefiles and open-source VHDL tools.

### Dependencies
To build and simulate the project, ensure the following tools are installed:

- **GHDL:** VHDL simulator for logic verification.
- **RISC-V Toolchain:** `riscv32-unknown-elf-gcc` (must support `-march=rv32i -mabi=ilp32`).
- **GNU Make:** Used to orchestrate the build and simulation process.
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

4. **View Waveforms:**
   ```bash
   gtkwave waves/hello_world.ghw
   ```

---

<p align="center">2026</p>
