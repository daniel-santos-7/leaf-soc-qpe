# Pulse Generator (QPE)

The waveform generator ([`ips/wgen`](../ips/wgen/)) is reached through one of two interfaces, chosen by the `leaf_soc` generic `WGEN_IF_COP` (Makefile `WGEN_IF`):

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

## DAC Port

While a pulse is active, `sig_i` and `sig_q` carry its samples; otherwise both carry the `dac_dat` input, which the board must drive (with 0 or its own rest level). A pulse always takes the pins. The outputs come from flip-flops in `dac_out` (one cycle of latency) and read 0 during reset. `dac_dat` is sampled on the rising edge of `clk` with no synchroniser, so the board must meet setup and hold there. `active` stays a `leaf_soc` port for integration and test; it does not go to a pad.

The I/Q width follows `OUT_RES_BITS` in the generated `ips/wgen/rtl/sine_lut_pkg.vhd` (currently 10 bits); do not hardcode it in `leaf_soc_pkg`.

## Sample Clock

`dac_clk` is the system clock inverted, generated in `dac_out`. The samples change just after the rising edge of `clk`, so `dac_clk` rises half a period later, in the middle of the data eye. It assumes a DAC that captures one sample per cycle on the rising edge of a data clock. In an ASIC the pin is a generated clock, with the DAC's setup and hold as output delays:

```tcl
create_generated_clock -name dac_clk -source [get_ports clk] -invert -divide_by 1 [get_ports dac_clk]
set_output_delay -clock dac_clk -max <DAC tSU> [get_ports {sig_i[*] sig_q[*]}]
set_output_delay -clock dac_clk -min -<DAC tH>  [get_ports {sig_i[*] sig_q[*]}]
```
