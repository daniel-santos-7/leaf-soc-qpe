# Known issues in `soc/rtl/`

Open issues only; fixed ones are removed, and their history is in git.
Entries are ordered by the effort their fix takes, simplest first; the
section at the end orders them by priority for the tapeout.

The entry below comes from a read of every file under `soc/rtl/` (`develop` @
`8d0689d`).

Issues opened on GitHub are tracked there and not repeated here:

- [#1](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/1): a trigger
  written while one is queued is lost;
- [#2](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/2): no sample
  clock goes out with `sig_i` / `sig_q`;
- [#3](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/3): `active`
  leads the I/Q samples by 5 cycles and is not registered;
- [#4](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/4): no trap
  vector is set, so any trap loops at address 0;
- [#5](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/5): no timer
  interrupt;
- [#6](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/6): set the XIP timing from the
  chosen flash's datasheet;
- [#7](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/7): XIP, abandon a
  fetch in flight on a redirect (enhancement);
- [#8](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/8): RAM0 macros,
  make a store and a fetch of the same word safe (enhancement).

Defects of the Leaf core are filed in its own repository: the duplicate `time`
counter ([leaf#6](https://github.com/daniel-santos-7/leaf/issues/6)) and the
CSR read-after-write bypass
([leaf#7](https://github.com/daniel-santos-7/leaf/issues/7)) and `FENCE.I`
executing as a no-op ([leaf#8](https://github.com/daniel-santos-7/leaf/issues/8)).

Each entry says whether it was **verified** (reproduced in simulation or
synthesis) or is **analysis** (read from the RTL, not yet observed).

---

## 1. COP pulses: software does not follow the pointer scheme, and a queued trigger launches with late values

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

The same change should settle what happens to a trigger written while one is
already queued, which is lost today: see GitHub issue
[#1](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/1).

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

- GitHub issue [#4](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/4), the boot ROM trap handler, because the ROM cannot
  change after tapeout. Test the whole bootloader with it, not just the
  handler.
- GitHub issue [#6](https://github.com/daniel-santos-7/leaf-soc-qpe/issues/6), the XIP timing: set
  `XIP_SCK_DIV` and `XIP_CS_HIGH_CYCLES` from the chosen flash's datasheet.
- **Issue 1**, because COP is the default interface and emits no pulse today;
  the snapshot in `qpe_csrs` is hardware and cannot follow in software.

This list does not replace the rest of the ASIC flow. Synthesis with the PDK
library and timing constraints, static timing analysis at the target clock,
gate-level simulation and DFT insertion are all still to be done. The generic
synthesis found no latches, no combinational loops and no multiple drivers,
one clock domain and a synchronous reset everywhere except the two flip-flops
of the reset synchroniser, which is a good starting point for all of them.
