# Known issues in `soc/rtl/`

Open issues only; fixed ones are removed, and their history is in git.
Entries are ordered by the effort their fix takes, simplest first; the
section at the end orders them by priority for the tapeout.

Issues 2 and 6 come from a read of every file under `soc/rtl/` (`develop` @
`1c06fa7`). Issues 1, 4, 7 and 9 come from a second pass aimed at the ASIC
tapeout (`develop` @ `d832821`), which also covered the RTL of the three IPs
and a generic Yosys synthesis of `leaf_soc` in both `WGEN_IF` modes. Issues 5,
10, 12 and 13 come from a third read of `soc/rtl/` (`develop` @ `8d0689d`),
issues 3, 8 and 11 from a fourth (`develop` @ `3aa5783`).

Each entry says whether it was **verified** (reproduced in simulation or
synthesis) or is **analysis** (read from the RTL, not yet observed). Issue 6
is a software issue.

---

## 1. The reset pin is active low but named `rst`

**Status:** verified in the testbench.
**Files:** `soc/rtl/wb_syscon.vhdl:28`, `soc/tbs/leaf_soc_tb.vhdl:145`, `:152`

`wb_syscon` asserts reset while `rst = '0'`, and the testbench holds
`rst = '0'` during reset and releases it to `'1'`. The polarity is only visible
by reading both. For the chip the pin's polarity goes into the padframe, the
timing constraints and the board design.

`wb_syscon` asserts `rst_o` asynchronously, so the SoC reset is active from
power-up and from the moment the pin goes low, clock or no clock. Every other
register, in `soc/rtl/` and in the IPs, still resets synchronously: nothing
else is reset until the clock has run a cycle with `rst_o` high. Outputs such
as `tx` and `spi_cs_n` are undefined at power-up until then, so the board must
supply the clock while reset is held.

The asynchronous assertion also makes any pulse on the pin, however short,
reset the whole chip, where a glitch between two clock edges used to be
ignored. The filtering belongs outside the RTL: a Schmitt-trigger input pad,
and a reset supervisor or an RC network on the board.

**Fix:** rename the port `rst_n`. Record with the pinout the clock-during-reset
requirement and the filtering the pin needs.

---

## 2. `qpe_csrs`: writes outside `0x7C0–0x7C6` are silently discarded

**Status:** analysis.
**File:** `soc/rtl/qpe_csrs.vhdl:98`

`when others => null;` — everything above `REG_TRIG` is dropped and reads
return zero. This is the hardware half of the mismatch with the banked
sequencer API in `sw/c/common/wgen.h`, which addresses
`0x7C0 + 5*bank + reg`. For bank 0 that range overlaps the flat registers
(bank 0 reg 3 is ENV in the banked layout but DRAG in the flat one), so those
calls corrupt the single-pulse configuration instead of failing.

**Fix:** until the banked CSR file exists, the software API should be removed
or made to fail loudly. See `README.md` for the current flat register map.

---

## 3. `qpe_csrs`: a trigger written while one is queued is lost

**Status:** analysis.
**Files:** `soc/rtl/qpe_csrs.vhdl:94-97`, `:135-136`, `sw/c/common/wgen.c:176-180`

The trigger queue holds one request. A `TRIG` write while `sig_gen` is busy
sets `valid_reg`; a second one before `ready` rises sets it again, so two
triggers give one pulse. A `TRIG` written in the cycle `ready` rises with
`valid_reg` set is lost as well: the write sees `ready = '1'`, leaves
`valid_reg` alone, and its `valid_int` merges with the queued request into the
single `sync` that `sig_gen_ctrl` takes. Nothing reports it: no error, no
counter, and `TRIG` reads back the same status as after one trigger.

Software that waits for bit 1 of `TRIG` (`ready and not valid`) before every
trigger, as `wgen_wait_ready()` and `qp.wait` do, never hits it. `wgen_pulse()`
does not wait, so two calls in a row without `wgen_wait_ready()` in between
emit one pulse. MMIO shares the first case (`sig_gen_csrs` also keeps a single
`valid_reg`) but not the second: there the write sets `valid_reg` after the
clear, so the trigger stays queued.

**Fix:** document in `README.md`, next to the pulse register map, that a
trigger must wait for bit 1 of `TRIG`, and make `wgen_pulse()` wait before it
triggers. When the hardware of issue 13 is done, decide there whether a second
trigger while one is queued is refused visibly (a sticky overflow bit in
`TRIG`) or queued deeper; with the snapshot registers each extra entry costs
152 flip-flops.

---

## 4. No sample clock goes out with `sig_i` / `sig_q`

**Status:** analysis.
**File:** `soc/rtl/leaf_soc.vhdl:21-23`

The I/Q samples leave the chip registered on the internal clock, one new
sample per cycle, but no pin carries a clock to latch them with. The external
DAC has to run from the board clock, and the output delay of 21 pins has to fit
inside one period with the DAC's setup and hold.

**Fix:** decide with the board design how the DAC is clocked. A forwarded clock
(an output pin driven from a flip-flop toggling in phase with the data) is the
usual answer.

---

## 5. `qpe_csrs`: the trigger reaches `sig_gen` through a long combinational path

**Status:** analysis. A timing risk, not a functional fault.
**Files:** `soc/rtl/qpe_csrs.vhdl:135-137`, `ips/cpu/rtl/csrs.vhdl:321`,
`ips/cpu/rtl/trap_ctrl.vhdl:77`, `:164`, `ips/cpu/rtl/dmls_block.vhdl:305-306`,
`ips/wgen/rtl/sig_gen_ctrl.vhd:101-117`

`valid_o` is combinational: `valid_int` is high in the same cycle as a `TRIG`
write, through `we_i`. Traced back into the core:

- `cop_we_o <= wr_en_i and cop_sel_wr` (`csrs.vhdl:321`);
- `wr_en_i` is `csrwr_en_o <= csrwr_en_i and not exc_fault` (`trap_ctrl.vhdl:164`);
- `exc_fault` ORs the misalignment checks on the EX address adder and on the
  branch target, and `dmld_fault`/`dmst_fault`, which are `data_err_i` from
  the bus gated with the access type (`dmls_block.vhdl:305-306`).

Forward, `valid_o` becomes `sync <= valid_i and ready` in `sig_gen_ctrl`,
which enables over a hundred parameter flip-flops and moves the state machine. The
likely worst path in one cycle is therefore: register file → operand
forwarding → EX adder → alignment check → `exc_fault` → `csrwr_en` →
`cop_we` → `valid_int` → `sync` → a high-fanout enable.

Functionally it is fine: with a CSR instruction in EX, `dmem_rd/wr` are `0`
and the address is irrelevant, but static timing analysis does not know that.
The core already has the same path into its own CSRs; the QPE extends it
across a block boundary and ends it on a wide enable. How much it costs
depends on the target clock and the PDK library, so it is not measurable
before that synthesis.

**Fix:** register the trigger in `qpe_csrs`, so that `valid_o` comes from a
flip-flop only. Every `TRIG` write is latched, and the pulse starts one cycle
later; reading `TRIG` (`ready and not valid`) still works, since `valid` is
visible from the next cycle on. It fits the hardware fix of issue 13: the
snapshot registers can load in the same cycle, and `sig_gen` then sees only
registers from `qpe_csrs`. The alternative is to wait for static timing
analysis with the PDK and only act if the path shows up as critical.

---

## 6. No trap vector is set, so any trap loops at address 0 (software)

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

## 8. MMIO mode: the COP CSR window is accepted silently

**Status:** analysis.
**Files:** `soc/rtl/leaf_soc.vhdl:185-188`, `:211`, `ips/cpu/rtl/csrs.vhdl:124-125`, `:149-150`

The core decodes `0x7C0–0x7FF` as the coprocessor window whether or not a
coprocessor is attached, and raises no exception for any CSR address. In MMIO
mode the plain `leaf` has its `cop_*` port tied off: `cop_dat_i` is `0` and
the write outputs are open. A program built for COP (every C build today,
since nothing defines `WGEN_IF_MMIO`) therefore runs on an MMIO SoC without a
fault: its parameter writes vanish and no pulse comes out. One that waits on
`TRIG` reads `0` forever and hangs in the poll.

The opposite mismatch is visible: an MMIO program on a COP SoC gets `err` on
IO1 and traps (issue 6).

**Fix:** in the CPU submodule, a generic that disables the window, so that an
access to it without a coprocessor is an illegal instruction; `leaf_soc` sets
it in `mmio_qpe_gen`. Until then, document the behaviour in `README.md` under
"Two ways to reach the pulse generator".

---

## 9. `time` duplicates `cycle`, and nothing can raise a timer interrupt

**Status:** analysis.
**Files:** `ips/cpu/rtl/counters.vhdl:48`, `soc/rtl/leaf_soc.vhdl:147-148`, `:183-184`

`counters` keeps `timer_reg` and `cycle_reg` as two identical 64-bit counters,
both incremented every clock: 64 flip-flops and an adder with no function.
The SoC ties `sw_irq_i` and `tm_irq_i` to `'0'` and has no `mtimecmp`, so
the chip has no timer interrupt; the GPIO on `ex_irq_i` is its only interrupt
source.

**Fix:** either drive `time` from a real time base with an `mtimecmp` that
raises `tm_irq_i`, or read `time` from the cycle counter and drop the
duplicate. The first is a change in the CPU submodule.

---

## 10. XIP: the SPI timing is fixed in the RTL and unchecked against a flash

**Status:** verified in simulation (the timing below); the datasheet check is
open until a flash is chosen.
**File:** `soc/rtl/wb_xip_ctrl.vhdl`

`wb_xip_ctrl` issues a plain `03h` READ per word and derives every SPI timing
from the system clock, with no parameter. Measured on `xip_test` with the
testbench's 100 MHz clock:

| Parameter | Where it comes from | Measured |
|-----------|---------------------|----------|
| SCK period | `sck` toggles every cycle: clock / 2 | 20 ns (50 MHz) |
| CS# high between reads (tSHSL) | `DONE` for one cycle, then `IDLE` takes the next request at once | 20 ns, every one of 117 gaps |
| CS# low to first SCK rise (tSLCH) | `IDLE` drops CS#, `SHIFT` raises SCK on the next cycle | 10 ns |
| last SCK rise to CS# high (tCHSH) | CS# rises with the last SCK fall | 10 ns |
| MISO sampling | sampled on the cycle SCK rises, half an SCK period after the fall that launched it | 10 ns for tCLQV plus pad and board delays |

During code execution from flash the fetches are back to back, so the CS# gap
is always the minimum; nothing in the RTL enforces a longer one. Every one of
these scales with the clock: a faster chip clock shortens them all.

**Fix:** when the flash is chosen, check against its datasheet:

- tSHSL, the minimum CS# deselect time, for the read command;
- fR, the maximum SCK frequency for `03h` (lower than for the fast-read
  commands on many parts);
- tCLQV, with the pad and board delays, against the half SCK period;
- tSLCH and tCHSH.

Before tapeout, parameterise `wb_xip_ctrl` with generics set from `leaf_soc`,
`CS_HIGH_CYCLES` (a counter that holds `IDLE`) and `SCK_DIV` (a divider for
SCK), so that the datasheet values do not force an RTL change late. Recheck
`xip_test`, whose cycle budget and the 130-cycle word latency in `README.md`
depend on both.

---

## 11. XIP: a fetch in flight cannot be abandoned

**Status:** analysis. Performance only.
**Files:** `soc/rtl/wb_xip_ctrl.vhdl`, `soc/rtl/wb_channel.vhdl:144-148`, `:158`

Once `wb_xip_ctrl` leaves `IDLE` it runs the whole 64-bit transfer, and
`wb_channel` holds `xip_sel_reg`, and with it `STALL`, until the `ACK`. When
the core redirects (a taken branch or a trap) while a sequential prefetch from
XIP is in flight, the fetch at the new target waits for the stale word: up to
a full word latency, 130 cycles, for an instruction that is thrown away. Code
running from flash pays it on every taken branch whose fall-through word was
already requested, including a jump from XIP into RAM0.

**Fix:** only if XIP performance matters. Let the core abandon the cycle by
dropping `CYC`, which Wishbone allows, and have `wb_xip_ctrl` return to `IDLE`
and `wb_channel` clear `xip_sel_reg` when it does. The core drops `CYC` today
only when its instruction buffer is full, not on a redirect, so the change
starts in the CPU submodule. Recheck `xip_test` after it.

---

## 12. RAM0 macros: a store and a fetch of the same word in one cycle

**Status:** analysis. Not seen in any test.
**Files:** `soc/rtl/wb_ram_dp_macro.vhdl`, `soc/tbs/sram_dp_sim.vhdl`,
`ips/cpu/rtl/main_ctrl.vhdl:311`

RAM0 is dual-port on one clock: port A for data, port B for instruction
fetch. When port A writes a word and port B reads the same word in the same
cycle:

| Model | Port B returns |
|-------|----------------|
| `wb_ram_dp` (`RAM=BEHAV`) | the old word, cleanly |
| `sram_dp(sim)` and the technology model (`RAM=MACRO`/`TECH`) | the whole word unknown |
| silicon | undefined: both ports drive the same cell |

The write itself lands. The macro also specifies a minimum clock separation
between its two ports for same-address accesses, which a single clock only
meets if the collision never happens.

It needs a store into a word the fetch unit is reading at that moment:

1. Code that writes instructions just ahead of the PC. `FENCE.I` does not help:
   the core decodes the `FENCE` opcode as a no-op (`main_ctrl.vhdl:311`), so it
   discards nothing already fetched. On silicon the fetched word can be garbage,
   an illegal instruction, and then the loop of issue 6.
2. Prefetch running past the end of `.text` into writable `.rodata`/`.data`
   while a store hits that word. The fetched word is flushed and never
   executed, but the collision still happens on the macro.

`ram1_test` copies code and jumps to it in RAM1, which is flip-flops and has no
such problem. The `RAM=MACRO`/`TECH` regressions matched `RAM=BEHAV` everywhere
except the read-data bus on write acks, so no current program collides. Nothing
would show it if one did: `BEHAV` returns the old word silently, and `MACRO`/
`TECH` put an unknown on a bus that only a waveform shows.

**Fix:**

- make it visible: a `report ... severity warning` on contention in
  `sram_dp(sim)` (and in the technology model), so a colliding program shows
  up in the `RAM=MACRO`/`TECH` log;
- document the rule for software in `README.md`: never store into
  instruction words inside the prefetch window; after writing code, jump to it,
  since the jump discards what was prefetched; do not rely on `FENCE.I`;
- in the CPU submodule, make `FENCE.I` flush the fetch buffers, as the
  RISC-V spec requires for the core to see its own instruction stores;
- only if self-modifying code in RAM0 is ever needed: detect the collision in
  `wb_ram_dp_macro` and delay port B one cycle. That needs a stall from RAM0 on
  the instruction channel, which `wb_intercon` only generates for XIP today.
  Forwarding the write data does not work: on a byte or half-word store the
  bytes not written also come out unknown.

---

## 13. COP pulses: software does not follow the pointer scheme, and a queued trigger launches with late values

**Status:** part A verified in simulation; part B analysis.
**Files:** `soc/rtl/qpe_csrs.vhdl:83-109`, `:135-137`, `sw/c/common/wgen.c`,
`sw/asm/common/qp.inc`, `ips/wgen/rtl/sig_gen_ctrl.vhd:101-117`

In COP mode `qpe_csrs` holds no pulse values. Writing a parameter CSR stores
`wdata(4 downto 0)` as a GPR index, and the block copies into a mirror every
value the CPU's register-file write port writes to that GPR. The mirrors drive
`sig_gen` directly, and `sig_gen_ctrl` samples them only when a pulse starts
(`valid_i and ready`).

### A. The software writes values where the hardware expects GPR indices

`wgen_write_ftw()` and the other COP setters in `wgen.c` do
`csrw WG_xxx, value`, and so do the `qp.*` macros used by the assembly
examples. The hardware reads the low five bits of each value as a register
number, binds the parameter to an arbitrary GPR, and the pulse gets whatever
that GPR happens to hold.

Verified: `sw/c/ramsey` in COP mode writes 507,855 active samples to the CSV,
every one of them `0,0`. The same flow in MMIO (`wgen_demo_mmio`) gives 10,583
non-zero samples out of 15,219. The assembly case (`xwg-test`) was already
seen to produce all-zero samples. As things stand, no program under `sw/`
emits a pulse in COP mode, which is the default.

### B. A trigger queued while busy picks up the values at launch

A write to `TRIG` while `sig_gen` is idle launches in the same cycle, with the
values the mirrors hold then. While `sig_gen` is busy, the request is kept in
`valid_reg` and launches when `ready` rises, possibly thousands of cycles
later, with whatever the mirrors hold at that point. Anything that writes a
bound GPR in between changes a pulse that was already requested:

1. the program preparing the next pulse in the same registers;
2. the compiler reusing the register as a temporary;
3. an interrupt handler (`ex_irq_i` is live since the GPIO) that uses the
   register, even if it saves and restores it;
4. a load: while it waits for `ack`, the core keeps the register-file write
   enabled every cycle with data not yet valid (`trap_ctrl.vhdl:163` gates it
   only with faults). The register file ends up right, but the mirror follows
   the transient values, and a launch in one of those cycles latches a value
   the program never produced.

MMIO has the same queue (`sig_gen_csrs` holds `valid_reg` until `ready`), but
there only an explicit store changes the values, so only case 1 applies.

### Fix

Hardware, in `qpe_csrs`: freeze the parameters at the trigger. On a `TRIG`
write while busy, copy the six mirrors into pending registers and feed
`sig_gen` from them while `valid_reg` is set. The trigger write happens with
the CSR instruction in EX, where no load can be pending, so all four cases go
away, and the semantics become "a pulse uses the values current at its
trigger". Cost: 152 flip-flops (FTW 32, POW 32, AMP 16, DRAG 16, ENV 32,
DELAY 24) and a 2:1 mux.

Software, once the hardware snapshots at the trigger:

- bind once: a `wgen_init()` that writes fixed GPR indices into the six
  parameter CSRs (`csrwi WG_FTW, 22`, …);
- load and fire in a single inline-`asm` block: move the six values into the
  bound GPRs and `csrwi WG_TRIG, 1`, with those GPRs in the clobber list so the
  compiler saves anything it kept there. Nothing can run between the moves and
  the trigger except an interrupt, whose handler restores the registers before
  returning;
- rewrite `qp.inc` and the assembly examples in the same bind-then-fill style.

Then check `ramsey`, `rabi`, `t1` and `wgen_demo` in COP with `SAMPLES=1`
against their MMIO output. Add a test for case 1: fire a long pulse, queue a
second one with `AMP1`, change the bound GPR to `AMP2`, and check the second
pulse's amplitude in the CSV.

---

## Suggested order

Before tapeout:

- **Issue 6**, the boot ROM trap handler, because the ROM cannot change after
  tapeout. Test the whole bootloader with it, not just the handler.
- **Issue 10**, the XIP timing: add the generics, then set them from the
  chosen flash's datasheet.
- **Issues 1 and 4**, because they fix the pinout.
- **Issue 13**, because COP is the default interface and emits no pulse today;
  the snapshot in `qpe_csrs` is hardware and cannot follow in software.
  Do issue 5 in the same change: it touches the same lines.

Then, in any order: issue 7 (timeout), issue 3, issue 8, issue 9, issue 11,
issue 12 and issue 2.

This list does not replace the rest of the ASIC flow. Synthesis with the PDK
library and timing constraints, static timing analysis at the target clock,
gate-level simulation and DFT insertion are all still to be done. The generic
synthesis found no latches, no combinational loops and no multiple drivers,
one clock domain and a synchronous reset everywhere except the two flip-flops
of the reset synchroniser, which is a good starting point for all of them.
