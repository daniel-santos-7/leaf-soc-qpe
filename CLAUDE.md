# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Leaf SoC with a **QPE** (quantum pulse extension): an RV32I SoC whose CPU drives a DDS
waveform generator that emits Gaussian, DRAG-corrected I/Q pulses for qubit control.
Everything is VHDL simulated with GHDL; there is no CI and no synthesis flow at the SoC level.

The three IPs in `ips/` are **git submodules** with their own Makefiles, READMEs and test
suites. Clone with `git submodule update --init --recursive`, and remember that changes under
`ips/` belong to the submodule repo, not this one.

## Build and simulate

Software is built per-program (each has its own Makefile), then handed to the SoC testbench
from the repo root:

```bash
make -C sw/c/hello_world                                  # -> sw/c/hello_world/hello_world.bin
make run PROGRAM=sw/c/hello_world/hello_world.bin
make clean                                                # ghdl clean + drops work/, waves/, wgen_cfg.vhdl
```

Root-Makefile knobs:

| Variable | Default | Notes |
|----------|---------|-------|
| `PROGRAM` | `sw/asm/hello-world/hello-world.bin` | `.bin` to run; also names the waveform/CSV outputs |
| `RUN_CYCLES` | `500000` | Simulated cycles after load. CoreMark needs tens of millions |
| `WGEN_IF` | `COP` | `COP` or `MMIO` — see "Two ways to reach the pulse generator" |
| `WAVEFORM` | *(none)* | `ghw` or `fst`; written to `waves/<program>.<ext>` |
| `SAMPLES` | *(none)* | `1` dumps every active I/Q sample to `waves/<program>.csv` |

`sw/Makefile` wraps the CoreMark benchmark and the serial upload helpers:

```bash
make -C sw run-quick             # build coremark + simulate, log to sw/logs/
make -C sw upload BIN=./c/hello_world/hello_world.bin PORT=/dev/ttyUSB0
make -C sw monitor PORT=/dev/ttyUSB0
```

Simulation output is the program's UART TX decoded to stdout, so `printf`/`uart_puts` is the
primary debugging channel; waveforms are the fallback.

`make plot` is currently broken — it references `sw/utils/plot_samples.py` and
`sw/utils/requirements.txt`, neither of which exists. Use `SAMPLES=1` and plot the CSV yourself.

### CPU instruction tests (submodule)

`ips/cpu/verif/tests` is a differential suite: each test runs on the Leaf RTL and on Spike, and
compares the register dumps. Needs `spike` on PATH.

```bash
make -C ips/cpu/verif/tests compare      # whole suite, keeps going past failures
make -C ips/cpu/verif/tests/addi compare # one test
```

A test directory is just `main.S` plus a Makefile that sets `DUMP_SIZE` and includes
`../common/common.mk`.

## Architecture

### Bus and memory map

Single Wishbone B4 master (the CPU) into `wb_intercon`, which address-decodes to five slaves.
Bases and widths are declared once in `soc/rtl/leaf_soc_pkg.vhdl` — that package is the source
of truth, and it also holds the component declarations for every SoC-level entity.

| Slave | Base | Size |
|-------|------|------|
| ROM | `0x00001000` | 512 B — bootloader |
| IO0 (UART) | `0x10000000` | 16 B |
| IO1 (WGEN, MMIO mode only) | `0x10001000` | 32 B |
| XIP (SPI flash) | `0x20000000` | 16 MB |
| RAM | `0x80000000` | 32 KB, dual-port (A=data, B=instruction) |

### Two ways to reach the pulse generator

`WGEN_IF` picks which one is elaborated. The root Makefile *generates* `soc/rtl/wgen_cfg.vhdl`
(a one-line package holding `WGEN_IF_COP : boolean`) and `leaf_soc.vhdl` selects between two
`generate` blocks on it. The file is gitignored and switching `WGEN_IF` requires no source
edits. Its rule is `FORCE`d and compares before rewriting: nothing in the rule's dependencies
encodes `WGEN_IF`, so a plain target would leave the previous mode's file in place and
`make run WGEN_IF=...` would silently build the mode you just switched away from.

- **COP (default)** — `leaf_wgx` replaces the plain `leaf` core. It instantiates
  `leaf` + `wgx_csrs` + `sig_gen` and exposes pulse parameters through the CPU's custom CSR
  window `0x7C0–0x7FF` (the core decodes `rw_addr(11 downto 6) = 011111` and forwards those
  accesses out its `cop_*` port). IO1 is tied off. Lowest-latency path: no bus transaction.
- **MMIO** — the plain `leaf` core plus `wb_sig_gen` hung off IO1 as an ordinary Wishbone
  peripheral.

Software abstracts over both: `sw/c/common/wgen.c` compiles to either CSR or MMIO accesses
under `#ifdef WGEN_IF_MMIO`. Note that no Makefile currently defines that macro, so C builds
are CSR/COP-only unless you add `-DWGEN_IF_MMIO`.

### Output resolution is the IP's, not the SoC's

`ips/wgen` is on the `10-bit-output` branch, so `sig_i`/`sig_q` are 10-bit. The width lives in
the generated `rtl/sine_lut_pkg.vhd` (`OUT_RES_BITS`), and `leaf_soc_pkg.vhdl` derives its own
`OUT_RES_BITS` from it — do not hardcode a width there, or the SoC ports stop matching
`sig_gen`'s and elaboration fails with "actual constraints don't match formal ones".

Expect half-scale I/Q at DRAG=0: `iq_mod` slices `(2N downto N+1)` rather than
`(2N-1 downto N)`, deliberately reserving one bit of headroom so the DRAG cross-terms cannot
overflow. Measured on a max-amplitude pulse: ±255 of ±511 at DRAG=0, ~±300 at DRAG≈1.0.

The IP briefly used VHDL-2008 bit-string literals here, but its `Restrict to VHDL-93` commit
switched the generator to plain binary literals (`"0011111111"`) and named `LUT_DEPTH`
constants. The whole design analyses under GHDL's default VHDL-93 — do not add `--std=08`.

`rtl/sig_gen_pkg.vhd` was **deleted** in that same commit, so the SoC no longer gets component
declarations from the IP. `leaf_soc.vhdl`, `leaf_wgx.vhdl` and `leaf_soc_pkg.vhdl` dropped their
`use work.sig_gen_pkg.all;` clauses, and `wb_sig_gen`/`sig_gen` are instantiated directly as
`entity work.<name>`. Instantiate any further IP entity the same way.

### wgx_csrs: pointers, not values

The non-obvious part of the QPE. `wgx_csrs` does **not** store pulse parameters directly.
Writing a CSR stores `wdata(4 downto 0)` as a **GPR index** ("this parameter lives in xN"), and
the block then *snoops the CPU's register-file write port* (`rf_wr_en/addr/data`, tapped out of
`id_stage`) to mirror whatever gets written to that GPR. The rationale, recorded in the RTL
comments: dedicated register-file read ports cost a read-mux each and synthesized badly.
Reading a parameter CSR returns the pointer, not the value.

`TRIG` (CSR `0x7C6`) is the exception: `valid_o` is combinatorial, so a trigger write is
consumed in the same cycle when `sig_gen` is idle; if it is busy, `valid_reg` latches the
request until `ready_i` rises. Reading `TRIG` gives `bit1 = ready and not valid`, which is what
the `qp.wait` macro polls.

Be careful when touching `sw/asm/common/qp.inc`: `qp.ftw s0` expands to `csrw WG_FTW, s0`,
which sends **s0's value** — under the pointer scheme the low 5 bits of that value are what
binds the parameter. The assembly examples in `sw/asm/` (`rabi`, `xwg-test`, `iq_pulse`, …)
were written against the older value-passing convention and load literal parameter values into
those registers, so under the current RTL they bind to arbitrary GPRs and **emit an all-zero
pulse** — verified by simulating `xwg-test`, which produces samples that are identically 0.
A sequence that works today binds first, then fills the GPRs:

```asm
li t0, 22
qp.amp t0          # AMP now tracks x22
li x22, 0x0000FFFF # ...and picks this up via the register-file snoop
```

### Program loading in the testbench

`make run` copies `PROGRAM` to `work/program.bin`. Three things then consume it:

1. `wb_ram_dp_sim` (the simulation-only RAM, swapped in by the `leaf_soc_tb_sim` configuration
   in `soc/tbs/leaf_soc_tb_cfg.vhdl`) preloads RAM from the hardcoded path `work/program.bin`
   in `leaf_soc_tb_pkg.vhdl`.
2. `spi_flash_model` is initialised with the same binary for the XIP path.
3. With RAM preloaded, the testbench only sends the bootloader's `RAM_JUMP_CMD` (`0x4A`) over
   UART and waits for an ACK, skipping the slow byte-by-byte upload. Passing `PROGRAM=` empty
   takes the `leaf_soc_send_program` path instead.

The boot ROM is not compiled from VHDL source: `sw/asm/boot/boot.py` converts `boot.bin` into
`boot_pkg.vhdl`. Changing the bootloader means `make -C sw/asm/boot` and copying the generated
package over `soc/rtl/boot_pkg.vhdl`.

## Software conventions

- `riscv32-unknown-elf-gcc`, `-march=rv32i -mabi=ilp32`. Two nearly identical templates:
  `sw/c/common/common.mk` (C, pulls in `crt0.S` + newlib `syscalls.c`) and
  `sw/asm/common/common.mk` (assembly). A program's Makefile sets `APP_EXE` and includes one.
- Every program links against `soc.ld`: RAM only, 32 KB at `0x80000000`.
- Pulse programs (`rabi`, `ramsey`, `t1`, `wgen_demo`, `seq_demo`) override `APP_SRC` to pull in
  `wgen.c` + `leaf.c` and deliberately drop `$(SYSCALLS)` — they use `leaf.c`'s UART helpers
  rather than newlib, to stay small.
- Build products (`.elf`, `.bin`, `.debug`) are gitignored; `.debug` is the objdump listing and
  is the fastest way to check what the compiler did with a pulse sequence.
- `sw/README.md` is in Portuguese and predates the current layout — several paths it cites
  (`sw/common/`, `sw/utils/upload.py`, `make leaf_sim`) no longer exist.

## Branches

`main` is the release branch; day-to-day work lands on `develop`, with `develop-wgen` and
`feature/qpe` as the integration branches for the waveform-generator and QPE work.
