# Known issues in `soc/rtl/`

Open issues only; fixed ones are removed, and their history is in git. Issues
1–4 come from a read of every file under `soc/rtl/` (`develop` @ `1c06fa7`).
Issues 5–9 come from a second pass aimed at the ASIC tapeout (`develop` @
`d832821`), which also covered the RTL of the three IPs and a generic Yosys
synthesis of `leaf_soc` in both `WGEN_IF` modes.

Each entry says whether it was **verified** (reproduced in simulation or
synthesis) or is **analysis** (read from the RTL, not yet observed). Issue 4
is a software issue.

---

## 1. `wb_syscon`: reset synchroniser has no initial value

**Status:** analysis.
**File:** `soc/rtl/wb_syscon.vhdl:16`

```vhdl
signal rst_sync : std_logic_vector(1 downto 0);
```

Never initialised and never reset. In simulation it starts as `'U'` and
propagates for two cycles. On an FPGA it powers up at `'0'` — reset
**deasserted**, which is the unsafe state: the design leaves reset before the
synchroniser has filled.

A reset synchroniser should power up with reset asserted.

**Fix:** `signal rst_sync : std_logic_vector(1 downto 0) := (others => '1');`

Separately, `README.md` describes this module as handling "global clock
buffering", but it only does `clk_o <= clk`. Either add the buffer or correct
the description.

---

## 2. `qpe_csrs`: writes outside `0x7C0–0x7C6` are silently discarded

**Status:** analysis.
**File:** `soc/rtl/qpe_csrs.vhdl:103`

`when others => null;` — everything above `REG_TRIG` is dropped and reads
return zero. This is the hardware half of the mismatch with the banked
sequencer API in `sw/c/common/wgen.h`, which addresses
`0x7C0 + 5*bank + reg`. For bank 0 that range overlaps the flat registers
(bank 0 reg 3 is ENV in the banked layout but DRAG in the flat one), so those
calls corrupt the single-pulse configuration instead of failing.

**Fix:** until the banked CSR file exists, the software API should be removed
or made to fail loudly. See `README.md` for the current flat register map.

---

## 3. Style inconsistencies

**Status:** analysis. Cosmetic, but they are the kind of thing that drifts.

- **Missing file headers.** `wb_syscon`, `wb_ram_dp`, `qpe_csrs`, `leaf_qpe`
  and `leaf_soc_pkg` lack the `-- Leaf project / module: / year` block that
  `wb_rom`, `wb_xip_ctrl` and `leaf_soc` carry.
- **Portuguese comments in an otherwise English codebase.**
  `wb_ram_dp.vhdl` has "Leitura contínua de ambas as portas"; every other
  comment under `soc/rtl/` is in English.
- **Pointless intermediate signals.** `leaf_qpe.vhdl:140-141` routes `sig_i_o`
  through `wgen_sig_i` and `active_o` through `wgen_active`, while `sig_q_o` is
  driven straight from the instance. All three can connect directly.

---

## 4. No trap vector is set, so any trap loops at address 0 (software)

**Status:** verified in simulation.
**Files:** `sw/asm/boot/start.S`, `sw/c/common/crt0.S`

Not a hardware defect: the privileged spec leaves `mtvec`'s reset value to the
implementation, and the Leaf core resets it to `0`
(`ips/cpu/rtl/csrs.vhdl:276`). Setting it before a trap can happen is
software's job, and nothing under `sw/` does — not the boot ROM, not `crt0.S`,
not the assembly examples. Only the CPU tests in `ips/cpu/verif/tests` write
`mtvec`.

`0x0` is outside the memory map (the ROM starts at `0x1000`), so the first trap
of any kind fetches from `0`, gets `err`, takes an instruction access fault and
traps to `0` again, forever. From the second round on, `mepc` and `mtval` read
`0`, so the address that caused the first trap is lost.

Reproduced with a two-instruction program, `li t0, 0x10000000` / `jr t0` (a
fetch from the UART, which is not routed to the instruction channel), in COP
mode:

```
 88145 ns  adr=0x10000000 stb=1 ack=1 err=0   -- ack for the last RAM fetch
 88155 ns  adr=0x10000004 stb=1 ack=0 err=1   -- err for the fetch at 0x10000000
 88165 ns  adr=0x10000008 stb=1 ack=0 err=1   -- prefetches, flushed by the trap
 88175 ns  adr=0x1000000c stb=1 ack=0 err=1
 88185 ns  adr=0x0        stb=1 ack=0 err=1   -- trap to mtvec = 0
 88195 ns  adr=0x4        stb=1 ack=0 err=1
 88205 ns  adr=0x8        stb=1 ack=0 err=1
 88215 ns  adr=0xc        stb=1 ack=0 err=1
 88225 ns  adr=0x0        ...                 -- and again, forever
```

28235 of the 37048 simulated cycles had `inst_err = 1`.

Unrouted and unmapped accesses no longer hang the CPU on the bus: they are
answered with `err`. But the program still never continues; the difference is
that this one is recoverable in software.

**Fix:** have the boot ROM point `mtvec` at a handler inside the ROM before it
jumps to the program, and have that handler report `mcause`, `mepc` and
`mtval` over the UART and stop. Every program, C or assembly, is then covered,
and one that wants its own handler just overwrites `mtvec`. Changing the boot
ROM means `make -C sw/asm/boot` and copying the generated package over
`soc/rtl/boot_pkg.vhdl`.

This has to land before tapeout. `boot_pkg.vhdl` becomes fixed logic in
silicon, and the UART bootloader is the only way to load a program: the chip
has no JTAG or debug port. Whatever the boot ROM does at tapeout, it does for
the life of the chip.

---

## 5. `wb_ram_dp` is inferred as flip-flops on `develop`

**Status:** verified in synthesis.
**File:** `soc/rtl/wb_ram_dp.vhdl:36-41`

RAM0 (32 KB) is written as four `mem_array`s of 8192 × 8 bits with two read
ports and one write port. Yosys keeps them as `$mem_v2` cells of exactly that
shape. A generic ASIC flow has no RAM to map them to and builds 262,144
flip-flops plus the read muxes, which dwarfs the rest of the chip. RAM1
(`soc_ram1`, 1 KB, the same entity with `BITS => 10`) adds another 8,192.

The macro-based version (`wb_ram_dp_tsmc`, eight TSDN65LPA2048X16M8M) only
exists on `feature/tsmc-ram`, which is one commit on top of `1619e06` and well
behind `develop`. It predates the port A write fix for back-to-back writes, the
interconnect rework, RAM1, XIP and the renames.

**Fix:** bring `wb_ram_dp_tsmc` onto `develop`, make it what `leaf_soc`
instantiates for synthesis (RAM1 needs a macro of its own, or stays as
flip-flops if 8 Kbit is acceptable), and rerun `sw/c/ram_test` and `soc/tbs/xcheck`
there.

---

## 6. The reset pin is active low but named `rst`

**Status:** verified in the testbench.
**Files:** `soc/rtl/wb_syscon.vhdl:23`, `soc/tbs/leaf_soc_tb.vhdl:123`, `:130`

`wb_syscon` synchronises `not rst`, and the testbench holds `rst = '0'` during
reset and releases it to `'1'`. The polarity is only visible by reading both.
For the chip the pin's polarity goes into the padframe, the timing constraints
and the board design.

The reset is also synchronous everywhere, including its assertion: until the
clock runs for a couple of cycles, nothing is reset. Outputs such as `tx` and
`spi_cs_n` are undefined at power-up until then, so the board must supply the
clock while reset is held.

**Fix:** rename the port `rst_n`. Record the clock-during-reset requirement
with the pinout.

---

## 7. No bus timeout

**Status:** analysis.
**Files:** `soc/rtl/wb_channel.vhdl`, `ips/cpu/rtl/dmls_block.vhdl`, `ips/cpu/rtl/if_stage.vhdl`

A routed slave that never answers leaves the CPU waiting forever: neither
`wb_channel` nor the CPU counts cycles, and there is no watchdog. Only reset
recovers. No slave does that today (XIP is the only one that answers late,
and it always answers), but any future slave with a bug of its own would.

**Fix:** a cycle counter in `wb_channel` that answers with `err` when a
request goes unanswered for N cycles, so the CPU traps instead of hanging.
Alternatively a watchdog that resets the chip.

---

## 8. `time` duplicates `cycle`, and nothing can raise a timer interrupt

**Status:** analysis.
**Files:** `ips/cpu/rtl/counters.vhdl:48`, `soc/rtl/leaf_soc.vhdl:121-123`

`counters` keeps `timer_reg` and `cycle_reg` as two identical 64-bit counters,
both incremented every clock: 64 flip-flops and an adder with no function.
The SoC ties `ex_irq_i`, `sw_irq_i` and `tm_irq_i` to `'0'` and has no
`mtimecmp`, so the chip has no interrupt source at all.

**Fix:** either drive `time` from a real time base with an `mtimecmp` that
raises `tm_irq_i`, or read `time` from the cycle counter and drop the
duplicate. The first is a change in the CPU submodule.

---

## 9. No sample clock goes out with `sig_i` / `sig_q`

**Status:** analysis.
**File:** `soc/rtl/leaf_soc.vhdl:16-18`

The I/Q samples leave the chip registered on the internal clock, one new
sample per cycle, but no pin carries a clock to latch them with. The external
DAC has to run from the board clock, and the output delay of 21 pins has to fit
inside one period with the DAC's setup and hold.

**Fix:** decide with the board design how the DAC is clocked. A forwarded clock
(an output pin driven from a flip-flop toggling in phase with the data) is the
usual answer.

---

## Suggested order

Before tapeout:

- **Issue 5**, the RAM. Nothing else matters until the RAM is a macro.
- **Issue 4**, the boot ROM trap handler, because the ROM cannot change after
  tapeout. Test the whole bootloader with it, not just the handler.
- **XIP**: the RTL is fixed and verified against `spi_flash_model`; check
  the SCK rate (half the system clock) and the MISO sampling margin against
  the real flash's datasheet and the pad delays.
- **Issues 6 and 9**, because they fix the pinout.

Then, in any order: issue 7 (timeout), issue 1, issue 8, issues 2 and 3.

This list does not replace the rest of the ASIC flow. Synthesis with the PDK
library and timing constraints, static timing analysis at the target clock,
gate-level simulation and DFT insertion are all still to be done. The generic
synthesis found no latches, no combinational loops and no multiple drivers,
one clock domain and a synchronous reset throughout, which is a good starting
point for all of them.
