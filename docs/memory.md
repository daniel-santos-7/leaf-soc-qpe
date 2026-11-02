# Memory

## Memory Map

| Peripheral | Base Address | Size | Description |
|------------|--------------|------|-------------|
| **ROM**    | `0x00001000` | 512 B | Bootloader |
| **UART**   | `0x10000000` | 16 B | Serial communication (IO0) |
| **IO1**    | `0x10001000` | 32 B | Pulse generator registers (MMIO mode only) |
| **GPIO**   | `0x10002000` | 64 B | General-purpose I/O, 8 pins (IO2) |
| **XIP**    | `0x20000000` | 16 MB | External SPI flash, execute-in-place |
| **RAM0**   | `0x80000000` | 1 KB | Scratch memory, flip-flops |
| **RAM1**   | `0x90000000` | 32 KB | Program memory, SRAM macros |

[`soc/rtl/leaf_soc_pkg.vhdl`](../soc/rtl/leaf_soc_pkg.vhdl) is the source of truth for bases and widths.

## RAMs

Both RAMs are optional, through the `leaf_soc` generics `RAM0_EN` (default `true`) and `RAM1_EN` (default `false`). An absent RAM answers every access with `ERR`. The programs in `sw/` are linked into RAM1, so an integration that runs them sets `RAM1_EN => true`; the testbench does.

Programs are linked into RAM1 (`sw/*/common/soc.ld`). RAM0 is a `NOLOAD` section, `.ram0`: it is never preloaded nor cleared by `crt0`. Put data there with `__attribute__((section(".ram0")))`; code must be copied in at run time.

## Boot ROM

`sw/asm/boot/start.S`, converted into `soc/rtl/boot_pkg.vhdl` by `boot.py`. It takes one command byte at a time on the UART and answers `NAK` to anything else:

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

## Macro-based RAM
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
