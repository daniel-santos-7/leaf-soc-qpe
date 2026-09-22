# Known issues in `soc/rtl/`

Findings from a read of every file under `soc/rtl/`, on `develop` @ `1c06fa7`.

Each entry says whether it was **verified** (reproduced in simulation) or is
**analysis** (read from the RTL, not yet observed). Ordered by severity.

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

**Fix:** guard the increment, e.g. `if bit_cnt < 63 then bit_cnt <= bit_cnt + 1; end if;`

---

## 2. XIP acknowledgements never reach the CPU

**Status:** analysis.
**Files:** `soc/rtl/wb_intercon.vhdl:125`, `:132`; `ips/cpu/rtl/if_stage.vhdl:128`

`wb_intercon` matches responses to requests through a registered slave select:

```vhdl
xip_sel_reg <= xip_sel and req;                                  -- :125, req = cyc and stb
cpu_ack_o   <= ... or (xip_ack_i and xip_sel_reg) or ...;        -- :132
```

`if_stage` is a pipelined fetcher — `inst_stb_o <= if_adr_buf_ready` — so it
issues a new address every cycle it can and drops `stb` once its address FIFO
fills. `wb_xip_ctrl` needs ~68 cycles per word. By the time it raises `ack_o`,
`xip_sel_reg` has long since gone low, and the `and` at line 132 discards the
acknowledgement. With no bus timeout anywhere, the fetch never completes.

The header comment at `wb_intercon.vhdl:17-21` already records that the
response mux assumes a one-cycle acknowledge and that XIP does not satisfy it.
The point here is that the consequence is a deadlock, not just reduced
throughput — combined with issue 1, the XIP peripheral is non-functional.

**Fix:** either a select FIFO in the interconnect, or stall the master for the
duration of a slow slave's transfer (`inst_stall_i` is currently tied to `'0'`
in `leaf_soc.vhdl:206`).

Related: issue #1 on GitHub, which is the same underlying mechanism — a request
that receives neither an acknowledge nor an error, with nothing to time it out.

---

## 3. `wb_xip_ctrl`: the whole `err_o` path is unreachable

**Status:** analysis.
**Files:** `soc/rtl/wb_xip_ctrl.vhdl:79-80`, `:121`; `soc/rtl/leaf_soc.vhdl:215`

```vhdl
err_o <= '1' when cyc_i = '1' and stb_i = '1' and we_i = '1' else '0';   -- :121
```

Two independent reasons this can never fire:

1. `err_o` is combinational on the request cycle, but the interconnect only
   admits it through `xip_sel_reg`, which is high one cycle *later* — by then
   `stb_i` has dropped.
2. XIP is wired only to the instruction channel, and that interconnect drives
   `cpu_we_i => '0'` (`leaf_soc.vhdl:215`). `we_i` is therefore never `'1'`.

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

## 6. `wgx_csrs`: writes outside `0x7C0–0x7C6` are silently discarded

**Status:** analysis.
**File:** `soc/rtl/wgx_csrs.vhdl:103`

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

- **Missing file headers.** `wb_syscon`, `wb_ram_dp`, `wgx_csrs`, `leaf_wgx`
  and `leaf_soc_pkg` lack the `-- Leaf project / module: / year` block that
  `wb_rom`, `wb_xip_ctrl` and `leaf_soc` carry.
- **Portuguese comments in an otherwise English codebase.**
  `wb_ram_dp.vhdl` has "handshake protege" and "Leitura contínua de ambas as
  portas"; every other comment under `soc/rtl/` is in English.
- **Pointless intermediate signals.** `leaf_wgx.vhdl:140-141` routes `sig_i_o`
  through `wgen_sig_i` and `active_o` through `wgen_active`, while `sig_q_o` is
  driven straight from the instance. All three can connect directly.

---

## Suggested order

Issue 4 is done. Issue 1 is a few lines and can go in immediately; issue 5 is a
one-line change with real consequences on hardware. Issue 2 is an architectural
decision (select FIFO versus stalling the master) and issue 3 falls out of
whatever is decided there.
