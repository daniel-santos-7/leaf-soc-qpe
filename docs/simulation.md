# Simulation

The whole design analyses as **VHDL-93** with GHDL.

## Dependencies
To build and simulate the project, ensure the following tools are installed:

- **GHDL:** VHDL simulator for logic verification.
- **RISC-V Toolchain:** `riscv32-unknown-elf-gcc` (must support `-march=rv32i -mabi=ilp32`).
- **GNU Make:** Used to orchestrate the build and simulation process.
- **Spike:** (Optional) Required only by the CPU differential test suite in `ips/cpu/verif/tests`.
- **GTKWave:** (Optional) Recommended for viewing `.ghw` waveform files.

## Running a Simulation

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

## Makefile Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PROGRAM` | `sw/asm/hello-world/hello-world.bin` | `.bin` to run; also names the waveform and CSV outputs |
| `RUN_CYCLES` | `500000` | Simulated cycles after load; CoreMark needs tens of millions |
| `WGEN_IF` | `COP` | `COP` or `MMIO` — see [Pulse Generator](qpe.md) |
| `RAM` | `BEHAV` | `BEHAV`, `MACRO` or `TECH` — see [Memory](memory.md#macro-based-ram) |
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

## Other Targets

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
