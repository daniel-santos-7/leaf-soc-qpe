# Known issues in `soc/rtl/`

Issues 1–9 come from a read of every file under `soc/rtl/`, on `develop` @
`1c06fa7`. Issues 10–16 come from a second pass aimed at the ASIC tapeout, on
`develop` @ `d832821`, which also covered the RTL of the three IPs and a generic
Yosys synthesis of `leaf_soc` in both `WGEN_IF` modes.

Each entry says whether it was **verified** (reproduced in simulation or
synthesis) or is **analysis** (read from the RTL, not yet observed). Issues 1–9
are ordered by severity. Issue 9 is the exception: a software issue, found
while testing issue 8.

---

## 1. `wb_xip_ctrl`: `bit_cnt` overflows its range on every read

**Status:** verified — a single XIP read aborts the simulation.
**File:** `soc/rtl/wb_xip_ctrl.vhdl:101`

`bit_cnt` is declared `natural range 0 to 63`. In the `TRANSFER` state the
increment and the exit condition are two independent statements:

```vhdl
else
    if bit_cnt >= 32 then
        rx_shift <= rx_shift(30 downto 0) & spi_miso;
    end if;
    bit_cnt <= bit_cnt + 1;          -- line 101
end if;

if bit_cnt = 63 and sck_phase = '1' then
    state <= CS_HOLD;
end if;
```

When `bit_cnt = 63` and `sck_phase = '1'`, the state moves to `CS_HOLD` *and*
`bit_cnt` is assigned 64, which is outside its range.

Reproduced with a standalone testbench driving one read request with a
one-cycle strobe:

```
./xip_tb:error: bound check failure at soc/rtl/wb_xip_ctrl.vhdl:101
  instance: .xip_tb(sim).dut@wb_xip_ctrl(rtl).P3
./xip_tb:error: simulation failed
```

This is latent only because nothing in `sw/` jumps to `0x20000000`, so no test
exercises the XIP path.

In silicon the counter is 6 bits wide, so 64 wraps to 0 and the state machine
still moves to `CS_HOLD`: this one aborts the simulation but is harmless on the
chip. Issues 2 and 10 are not.

**Fix:** guard the increment, e.g. `if bit_cnt < 63 then bit_cnt <= bit_cnt + 1; end if;`

---

## 2. XIP acknowledgements never reach the CPU

**Status:** analysis.
**Files:** `soc/rtl/wb_channel.vhdl:116`, `:123`; `ips/cpu/rtl/if_stage.vhdl:128`

`wb_channel` matches responses to requests through a registered slave select:

```vhdl
xip_sel_reg <= xip_sel and req;                                  -- :116, req = cyc and stb
cpu_ack_o   <= ... or (xip_ack_i and xip_sel_reg) or ...;        -- :123
```

`if_stage` is a pipelined fetcher — `inst_stb_o <= if_adr_buf_ready` — so it
issues a new address every cycle it can and drops `stb` once its address FIFO
fills. `wb_xip_ctrl` needs ~68 cycles per word. By the time it raises `ack_o`,
`xip_sel_reg` has long since gone low, and the `and` at line 123 discards the
acknowledgement. With no bus timeout anywhere, the fetch never completes.

The "Bus & Interconnect" section of `README.md` already records that the
response mux assumes a one-cycle acknowledge and that XIP does not satisfy it.
The point here is that the consequence is a deadlock, not just reduced
throughput — combined with issue 1, the XIP peripheral is non-functional.

**Fix:** either a select FIFO in the interconnect, or stall the master for the
duration of a slow slave's transfer (`wb_channel` drives `cpu_stall_o`, which
reaches the CPU's `inst_stall_i`, to a constant `'0'` at `wb_channel.vhdl:125`).

Related: issue #1 on GitHub, which is the same underlying mechanism — a request
that receives neither an acknowledge nor an error, with nothing to time it out.

---

## 3. `wb_xip_ctrl`: the whole `err_o` path is unreachable

**Status:** analysis.
**Files:** `soc/rtl/wb_xip_ctrl.vhdl:79-80`, `:121`; `soc/rtl/wb_intercon.vhdl:89`

```vhdl
err_o <= '1' when cyc_i = '1' and stb_i = '1' and we_i = '1' else '0';   -- :121
```

Two independent reasons this can never fire:

1. `err_o` is combinational on the request cycle, but the interconnect only
   admits it through `xip_sel_reg` in `wb_channel`, which is high one cycle *later* — by then
   `stb_i` has dropped.
2. XIP is routed only from the instruction master, and the interconnect drives
   `cpu_we_i => '0'` into its channel (`wb_intercon.vhdl:89`). `we_i` is therefore never `'1'`.

The same applies to the `if we_i = '1' then null;` branch in `IDLE`
(`:79-80`). Three pieces of logic that cannot execute.

**Fix:** register `err_o` the way `ack_o` is handled, and decide whether XIP
should be reachable from the data channel at all. If it should not, drop the
write path rather than leaving it as dead code.

---

## 4. `wb_ram_dp`: classic write guard inside a pipelined slave — FIXED

**Status:** fixed. Was verified with a standalone testbench before the change.
**Files:** `soc/rtl/wb_ram_dp.vhdl`, `soc/tbs/wb_ram_dp_sim.vhdl`

The acknowledge is pipelined and unconditional:

```vhdl
ack_reg <= ram_req;
```

but the port A write still carries the classic-handshake guard:

```vhdl
if ack_reg = '0' and ram_req = '1' then
    if we_i = '1' then ... end if;
end if;
```

On two requests in consecutive cycles the second one sees `ack_reg = '1'`, so
**the write is silently dropped while the transfer is still acknowledged** —
data corruption with no error anywhere.

It cannot happen today because `dmls_block` walks `IDLE → REQUEST → WACCESS →
DONE` and never asserts `stb` on consecutive cycles. It becomes reachable the
moment the data master is allowed to pipeline. The read path is already
unconditional and correct.

A standalone testbench issuing two writes on consecutive cycles, then reading
both back, showed the failure on the original RTL:

```
addr 4 = 715788561          -- 0x2AAA1111, first write landed
addr 5 = 0                  -- uninitialised: metavalue
FAIL: second (back-to-back) write lost
```

and passes after the change:

```
addr 4 = 715788561          -- 0x2AAA1111
addr 5 = 1002119714         -- 0x3BBB2222
PASS: both back-to-back writes landed
```

**Fix applied:** dropped `ack_reg = '0'` from the guard, leaving
`if ram_req = '1'`. Note that `soc/tbs/wb_ram_dp_sim.vhdl` carried a verbatim
copy of the same guard and was corrected identically — the SoC testbench binds
`soc_ram` to that entity, not to `wb_ram_dp`, so fixing only the design source
would have left the simulated behaviour unchanged.

---

## 5. `wb_syscon`: reset synchroniser has no initial value

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

## 6. `qpe_csrs`: writes outside `0x7C0–0x7C6` are silently discarded

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

## 7. Style inconsistencies

**Status:** analysis. Cosmetic, but they are the kind of thing that drifts.

- **Missing file headers.** `wb_syscon`, `wb_ram_dp`, `qpe_csrs`, `leaf_qpe`
  and `leaf_soc_pkg` lack the `-- Leaf project / module: / year` block that
  `wb_rom`, `wb_xip_ctrl` and `leaf_soc` carry.
- **Portuguese comments in an otherwise English codebase.**
  `wb_ram_dp.vhdl` has "handshake protege" and "Leitura contínua de ambas as
  portas"; every other comment under `soc/rtl/` is in English.
- **Pointless intermediate signals.** `leaf_qpe.vhdl:140-141` routes `sig_i_o`
  through `wgen_sig_i` and `active_o` through `wgen_active`, while `sig_q_o` is
  driven straight from the instance. All three can connect directly.

---

## 8. Unrouted accesses hung the CPU instead of faulting — FIXED

**Status:** fixed. Was verified in simulation before the change.
**Files:** `soc/rtl/wb_intercon.vhdl`, `soc/rtl/wb_channel.vhdl`, `soc/rtl/leaf_soc.vhdl`

The SoC instantiated `wb_intercon` twice, once per CPU channel, each a
decoder for the whole five-slave map with the slaves of the other channel tied
off (`ack => '0'`). An address in a tied-off region still decoded as a hit, so
`sel_err` stayed low and the access received neither `ack` nor `err`: a load
from ROM or XIP, a store to XIP, or a fetch from the UART stalled the CPU
forever.

`wb_intercon` is now the single INTERCON of the Wishbone spec: one module with
an instruction and a data master port, arranged as a partial crossbar (inst →
ROM, XIP, RAM B; data → UART, IO1, RAM A). Inside it, one `wb_channel` per master
(the old intercon, plus an `err_i` per slave) has the slaves not routed to that
master tied off with `ack => '0'` and `err => '1'`, so an access to one of them,
like an unmapped address, gets `err` one cycle later, which the CPU takes as an
access fault. Routed accesses are unchanged: the CPU-side bus trace
(`soc_cpu_inst_*`, `soc_cpu_data_*`) is identical cycle for cycle before and
after for `hello_world` (C and asm) and `ramsey` in COP mode, and for
`hello_world` and an MMIO build of `wgen_demo` in MMIO mode, including the
10583 non-zero I/Q samples the latter emits.

A probe doing one unrouted access of each kind, with a trap handler that
prints `mcause`, in both `WGEN_IF` modes:

```
before:  rom load:                  -- hangs here
after:   rom load: F                -- mcause 5, load access fault
         xip store: H               -- mcause 7, store access fault
         uart fetch: B              -- mcause 1, instruction access fault
         end
```

---

## 9. No trap vector is set, so any trap loops at address 0 (software)

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

The CPU no longer stalls on the bus (issue 8), but the program still never
continues; the difference is that this one is recoverable in software.

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

## 10. `wb_xip_ctrl`: the flash receives command `0x01` instead of `0x03`

**Status:** verified in simulation.
**File:** `soc/rtl/wb_xip_ctrl.vhdl:56`, `:61`, `:95`, `:99`

`sck_phase` toggles in every state except `IDLE`, so it is already `'1'` in the
first `TRANSFER` cycle, and `spi_clk` (`:61`) rises right away. `spi_mosi` is
only loaded in the `sck_phase = '0'` cycles (`:95`), which come after that
first edge. The flash therefore samples a stale MOSI on the first rising edge
and every bit after it one edge late.

A standalone testbench driving one read request and shifting in MOSI on the
first 8 rising edges of `spi_clk`:

```
command byte seen by the flash on the first 8 SCK rising edges: 00000001
```

`0x01` is Write Status Register on common SPI flashes, not Read (`0x03`). It is
ignored without a preceding Write Enable, so nothing gets written, but the read
never happens. The address that follows is shifted the same way.

Separately, `rx_shift` samples `spi_miso` (`:99`) in the cycle where SCK is
high, i.e. on the clock edge that also drops SCK. The flash changes MISO after
the falling edge, so this depends on the flash's output hold time with no
margin for pad and board delays.

**Fix:** load the first MOSI bit before SCK can rise (for example in
`CS_SETUP`), and sample MISO on the SCK rising edge. The testbench's
`spi_flash_model` already checks for `0x03` (`soc/tbs/spi_flash_model.vhdl:97`),
so it would reject today's transfer; no SoC simulation gets that far because
of issues 1 and 2.

---

## 11. `wb_ram_dp` is inferred as flip-flops on `develop`

**Status:** verified in synthesis.
**File:** `soc/rtl/wb_ram_dp.vhdl:36-41`

The 32 KB RAM is written as four `mem_array`s of 8192 × 8 bits with two read
ports and one write port. Yosys keeps them as `$mem_v2` cells of exactly that
shape. A generic ASIC flow has no RAM to map them to and builds 262,144
flip-flops plus the read muxes, which dwarfs the rest of the chip.

The macro-based version (`wb_ram_dp_tsmc`, eight TSDN65LPA2048X16M8M) only
exists on `feature/tsmc-ram`, which is one commit on top of `1619e06` and 10
commits behind `develop`. It predates issue 4's fix, the interconnect rework
and the renames.

**Fix:** bring `wb_ram_dp_tsmc` onto `develop`, make it what `leaf_soc`
instantiates for synthesis, and rerun `sw/c/ram_test` and `soc/tbs/xcheck`
there.

---

## 12. `wb_xip_ctrl`: `spi_clk` is a combinational output

**Status:** analysis.
**File:** `soc/rtl/wb_xip_ctrl.vhdl:61`

```vhdl
spi_clk <= sck_phase when state = TRANSFER else '0';
```

The pin that clocks the external flash is a register ANDed with a decode of
the state register. When `state` changes more than one bit at once, as in
`CS_SETUP → TRANSFER` with a binary encoding, the decode can glitch, and the
glitch goes straight to a clock pin. Synthesis may also choose a different
encoding, so the RTL gives no guarantee either way.

**Fix:** drive `spi_clk` from a flip-flop, computed one cycle ahead.

---

## 13. The reset pin is active low but named `rst`

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

## 14. No bus timeout

**Status:** analysis.
**Files:** `soc/rtl/wb_channel.vhdl`, `ips/cpu/rtl/dmls_block.vhdl`, `ips/cpu/rtl/if_stage.vhdl`

A routed slave that never answers leaves the CPU waiting forever: neither
`wb_channel` nor the CPU counts cycles, and there is no watchdog. Only reset
recovers. On the chip this is reachable today through issue 2 (any fetch from
XIP), and it would be again for any future slave with a bug of its own.

**Fix:** a cycle counter in `wb_channel` that answers with `err` when a
request goes unanswered for N cycles, so the CPU traps instead of hanging.
Alternatively a watchdog that resets the chip.

---

## 15. `time` duplicates `cycle`, and nothing can raise a timer interrupt

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

## 16. No sample clock goes out with `sig_i` / `sig_q`

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

Issues 4 and 8 are done.

Before tapeout:

- **Issue 11**, the RAM. Nothing else matters until the RAM is a macro.
- **Issue 9**, the boot ROM trap handler, because the ROM cannot change after
  tapeout. Test the whole bootloader with it, not just the handler.
- **XIP (issues 1, 2, 3, 10, 12)**: either fix all five and verify the path
  against a flash model, or leave XIP out of the tapeout and free its four
  pins. Half a fix leaves a region that hangs the CPU (issue 2).
- **Issues 13 and 16**, because they fix the pinout.

Then, in any order: issue 14 (timeout), issue 5, issue 15, issues 6 and 7.

This list does not replace the rest of the ASIC flow. Synthesis with the PDK
library and timing constraints, static timing analysis at the target clock,
gate-level simulation and DFT insertion are all still to be done. The generic
synthesis found no latches, no combinational loops and no multiple drivers,
one clock domain and a synchronous reset throughout, which is a good starting
point for all of them.
