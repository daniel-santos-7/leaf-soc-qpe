-- Drop-in replacement for wb_ram_dp built out of TSMC TSDN65LPA2048X16M8M
-- dual-port SRAM macros instead of an inferred array.
--
-- ---------------------------------------------------------------------------
-- The macro
-- ---------------------------------------------------------------------------
-- ram.v in the repo root is the vendor simulation model; its header identifies
-- the library as "TSMC 65nm Low Power DP_SRAM Memory with BIST Interface" and
-- the geometry is baked into the cell name: 2048 words x 16 bits.  Three
-- parameters describe it, and they are not free knobs -- they are what the
-- memory compiler emitted.  A different depth or width means a different cell.
--
--     N = 16     data bits per word
--     W = 2048   words
--     M = 11     address bits (2**11 = 2048)
--
-- The model carries three more parameters that are not hardware: MES_ALL turns
-- its runtime warnings on and off, and cdeFileInit / cdeFileFault only exist
-- under `+TSMC_INITIALIZE_MEM` / `+TSMC_INITIALIZE_FAULT`.  They are absent from
-- the component declaration below on purpose.
--
-- Three naming rules account for all 27 pins:
--
--   * suffix A / B  -- the port.  This is a true dual-port SRAM: two fully
--                      independent ports, each with its own clock, each able to
--                      read *and* write.
--   * trailing B    -- "bar", i.e. ACTIVE LOW: WEB, CEB, BWEB.  This is the
--                      easy one to get wrong: CEBA = '0' means port A is busy.
--   * infix M       -- the mirrored BIST set (AMA, DMA, WEBMA, ...), so a
--                      memory-BIST controller can take the array over without
--                      putting multiplexers in the functional path.
--
-- Functional port A -- here the Wishbone data channel, read and write:
--
--     CLKA   in   1   port A clock; everything is sampled on the rising edge
--     CEBA   in   1   chip enable, active low.  '1' = port idle and QA HOLDS
--     WEBA   in   1   write enable, active low, qualified by CEBA = '0'
--     AA     in   M   address
--     DA     in   N   write data
--     BWEBA  in   N   per-BIT write mask, active low: bit i at '0' stores
--                     DA(i), at '1' leaves that bit of the word alone.  This is
--                     what carries the Wishbone byte selects
--     QA     out  N   read data
--
-- Functional port B -- same pins with a B suffix (CLKB, CEBB, WEBB, AB, DB,
-- BWEBB, QB) and the same capability.  It is the instruction channel here, so
-- this wrapper ties it read-only, but the silicon would write through it.
--
-- The rule worth internalising: **Q only moves on a read cycle**.  A write
-- cycle, or CEB = '1', leaves Q holding whatever the last read produced.  There
-- is no write-through -- writing and reading one address in the same cycle does
-- not return the new data.  Read latency is one cycle: address on edge n, data
-- valid just after that edge and stable until the next read.
--
-- Contention, when both ports hit the same address on the same cycle -- a real
-- electrical fight in silicon, modelled as unknowns:
--
--     A reads,  B writes   ->  QA unknown
--     B reads,  A writes   ->  QB unknown
--     A writes, B writes   ->  bits enabled by both masks go unknown
--
-- There is also a minimum clock separation, cksep = 1.068 ns between CLKA and
-- CLKB on a same-address access, checked by $recrem in the vendor model.  Both
-- ports run off clk_i here, i.e. zero separation, which is only safe because
-- the data and instruction addresses never coincide.  Worth remembering before
-- letting software write into its own .text.
--
-- BIST interface: AMA/DMA/BWEBMA/WEBMA/CEBMA mirror port A, AMB/... mirror port
-- B, CLKM clocks both, and BIST = '1' hands the array to that set.  Tied off
-- below (BIST = '0', every CEBM* = '1').
--
-- AWT is Asynchronous Write Through, a test mode that bypasses the array
-- entirely: with AWT = '1', QA becomes DA xor BWEBA combinationally (or
-- DMA xor BWEBMA when BIST = '1'; ram.v:1968-1985), and likewise for port B.
-- It neither reads nor writes memory -- it exercises the I/O paths without
-- depending on the cells.  Tied to '0'.
--
-- ---------------------------------------------------------------------------
-- This wrapper
-- ---------------------------------------------------------------------------
-- The SoC wants 8192 words x 32 bits and one macro gives 2048 x 16, hence a
-- 4 (depth) x 2 (width) array:
--
--                          bits 31..16        bits 15..0
--     bank 0  words     0..2047    macro(0,hi)   macro(0,lo)
--     bank 1  words  2048..4095    macro(1,hi)   macro(1,lo)
--     bank 2  words  4096..6143    macro(2,hi)   macro(2,lo)
--     bank 3  words  6144..8191    macro(3,hi)   macro(3,lo)
--
-- The Wishbone address adr_i is a word address: the low M bits index inside a
-- macro, the bits above them select the bank.  Only the addressed bank is
-- enabled (CEB low); the other three hold their outputs, which is why the bank
-- index has to be registered to steer the read mux one cycle later.  sel_i maps
-- onto BWEB one byte lane at a time: sel_i(0..1) into the low macro, sel_i(2..3)
-- into the high one.
--
-- Interface timing is identical to wb_ram_dp: ack one cycle after the request,
-- read data valid on the ack cycle, one write per transaction.
--
-- This file is design source only: there is nothing simulation-specific in it,
-- no file I/O and no preload hook.  The macro is a black box that comes from the
-- vendor library, so it is declared as a *component* carrying exactly the three
-- parameters the real cell has -- N, W and M (ram.v:81-83) -- and instantiated
-- against that declaration.  Whatever supplies the entity behind the component
-- is somebody else's problem: the vendor library in a real build, and
-- soc/tbs/tsdn65lpa2048x16m8m.vhdl under GHDL, picked up by the default binding
-- rule.
--
-- Preloading the array for simulation is likewise not this file's business.
-- soc/tbs/wb_ram_dp_tsmc_cfg.vhdl does it with a VHDL configuration that rebinds
-- each macro instance below to the model's preload generics, which is why the
-- instantiations here are components rather than direct entity references -- a
-- configuration cannot reach a direct entity instantiation.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity wb_ram_dp_tsmc is
    generic (
        BITS : natural := 15
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;

        -- Port A: data channel (read-write, byte selects)
        dat_i   : in  std_logic_vector(31 downto 0);
        cyc_i   : in  std_logic;
        stb_i   : in  std_logic;
        we_i    : in  std_logic;
        sel_i   : in  std_logic_vector(3 downto 0);
        adr_i   : in  std_logic_vector(BITS-3 downto 0);
        ack_o   : out std_logic;
        dat_o   : out std_logic_vector(31 downto 0);

        -- Port B: instruction channel (read-only, full word)
        cyc_b_i : in  std_logic;
        stb_b_i : in  std_logic;
        adr_b_i : in  std_logic_vector(BITS-3 downto 0);
        ack_b_o : out std_logic;
        dat_b_o : out std_logic_vector(31 downto 0)
    );
end entity wb_ram_dp_tsmc;

architecture rtl of wb_ram_dp_tsmc is

    -- Geometry of one TSDN65LPA2048X16M8M.
    constant MACRO_N : natural := 16;
    constant MACRO_W : natural := 2048;
    constant MACRO_M : natural := 11;

    constant WORDS : natural := 2**BITS / 4;       -- 32-bit words in the RAM
    constant BANKS : natural := WORDS / MACRO_W;   -- macros in depth

    subtype macro_addr_t is std_logic_vector(MACRO_M-1 downto 0);
    subtype half_t       is std_logic_vector(MACRO_N-1 downto 0);

    type half_array_t is array (0 to BANKS-1) of half_t;

    signal ram_req   : std_logic;
    signal ram_req_b : std_logic;

    signal ack_reg   : std_logic := '0';
    signal ack_reg_b : std_logic := '0';

    signal a_rd, a_wr : std_logic;

    signal bank_a, bank_b : natural range 0 to BANKS-1;
    signal sel_a, sel_b   : natural range 0 to BANKS-1;

    signal addr_a : macro_addr_t;
    signal addr_b : macro_addr_t;

    signal ceb_a : std_logic_vector(BANKS-1 downto 0);
    signal ceb_b : std_logic_vector(BANKS-1 downto 0);
    signal web_a : std_logic;

    -- Per-bit write mask, active low.
    signal bweb_lo : half_t;
    signal bweb_hi : half_t;

    signal q_lo_a, q_hi_a : half_array_t;
    signal q_lo_b, q_hi_b : half_array_t;

    -- The vendor cell, exactly as the vendor parameterises it.  A simulation
    -- model may carry extra generics; they are deliberately not visible here.
    component TSDN65LPA2048X16M8M is
        generic (
            N : natural := 16;
            W : natural := 2048;
            M : natural := 11
        );
        port (
            AA    : in  std_logic_vector(MACRO_M-1 downto 0);
            DA    : in  std_logic_vector(MACRO_N-1 downto 0);
            BWEBA : in  std_logic_vector(MACRO_N-1 downto 0);
            WEBA  : in  std_logic;
            CEBA  : in  std_logic;
            CLKA  : in  std_logic;

            AB    : in  std_logic_vector(MACRO_M-1 downto 0);
            DB    : in  std_logic_vector(MACRO_N-1 downto 0);
            BWEBB : in  std_logic_vector(MACRO_N-1 downto 0);
            WEBB  : in  std_logic;
            CEBB  : in  std_logic;
            CLKB  : in  std_logic;

            AMA    : in  std_logic_vector(MACRO_M-1 downto 0);
            DMA    : in  std_logic_vector(MACRO_N-1 downto 0);
            BWEBMA : in  std_logic_vector(MACRO_N-1 downto 0);
            WEBMA  : in  std_logic;
            CEBMA  : in  std_logic;

            AMB    : in  std_logic_vector(MACRO_M-1 downto 0);
            DMB    : in  std_logic_vector(MACRO_N-1 downto 0);
            BWEBMB : in  std_logic_vector(MACRO_N-1 downto 0);
            WEBMB  : in  std_logic;
            CEBMB  : in  std_logic;

            AWT  : in  std_logic;
            BIST : in  std_logic;
            CLKM : in  std_logic;

            QA : out std_logic_vector(MACRO_N-1 downto 0);
            QB : out std_logic_vector(MACRO_N-1 downto 0)
        );
    end component TSDN65LPA2048X16M8M;

    constant BWEB_NONE : half_t        := (others => '1');
    constant ADDR_ZERO : macro_addr_t  := (others => '0');
    constant DATA_ZERO : half_t        := (others => '0');

begin

    assert WORDS >= MACRO_W and WORDS mod MACRO_W = 0
        report "wb_ram_dp_tsmc: 2**BITS/4 must be a whole number of MACRO_W words"
        severity failure;

    ram_req   <= cyc_i   and stb_i;
    ram_req_b <= cyc_b_i and stb_b_i;

    -- A transaction is one read or one write; the ack_reg guard reproduces
    -- wb_ram_dp's "write only on the request cycle, not on the ack cycle".
    a_rd <= ram_req and not we_i;
    a_wr <= ram_req and we_i and not ack_reg;

    addr_a <= adr_i(MACRO_M-1 downto 0);
    addr_b <= adr_b_i(MACRO_M-1 downto 0);

    bank_gt1 : if BANKS > 1 generate
        bank_a <= to_integer(unsigned(adr_i(adr_i'high downto MACRO_M)));
        bank_b <= to_integer(unsigned(adr_b_i(adr_b_i'high downto MACRO_M)));
    end generate bank_gt1;

    bank_eq1 : if BANKS = 1 generate
        bank_a <= 0;
        bank_b <= 0;
    end generate bank_eq1;

    web_a <= '0' when a_wr = '1' else '1';

    -- Byte select -> per-bit active-low write mask, one byte lane at a time.
    -- sel_i(0) covers data bits 7..0, sel_i(1) bits 15..8 -> low macro;
    -- sel_i(2) bits 23..16, sel_i(3) bits 31..24 -> high macro.
    bweb_lo(15 downto 8) <= (others => not sel_i(1));
    bweb_lo( 7 downto 0) <= (others => not sel_i(0));
    bweb_hi(15 downto 8) <= (others => not sel_i(3));
    bweb_hi( 7 downto 0) <= (others => not sel_i(2));

    enable_proc : process (a_rd, a_wr, ram_req_b, bank_a, bank_b)
    begin
        for b in 0 to BANKS-1 loop
            if (a_rd = '1' or a_wr = '1') and bank_a = b then
                ceb_a(b) <= '0';
            else
                ceb_a(b) <= '1';
            end if;

            if ram_req_b = '1' and bank_b = b then
                ceb_b(b) <= '0';
            else
                ceb_b(b) <= '1';
            end if;
        end loop;
    end process enable_proc;

    macros : for b in 0 to BANKS-1 generate

        macro_lo : TSDN65LPA2048X16M8M
            generic map (
                N => MACRO_N,
                W => MACRO_W,
                M => MACRO_M
            )
            port map (
                -- Port A: data channel, read-write with per-bit write mask
                AA     => addr_a,
                DA     => dat_i(15 downto 0),
                BWEBA  => bweb_lo,
                WEBA   => web_a,
                CEBA   => ceb_a(b),
                CLKA   => clk_i,

                -- Port B: instruction channel, read-only
                AB     => addr_b,
                DB     => DATA_ZERO,
                BWEBB  => BWEB_NONE,
                WEBB   => '1',
                CEBB   => ceb_b(b),
                CLKB   => clk_i,

                -- BIST port A: unused, held inactive
                AMA    => ADDR_ZERO,
                DMA    => DATA_ZERO,
                BWEBMA => BWEB_NONE,
                WEBMA  => '1',
                CEBMA  => '1',

                -- BIST port B: unused, held inactive
                AMB    => ADDR_ZERO,
                DMB    => DATA_ZERO,
                BWEBMB => BWEB_NONE,
                WEBMB  => '1',
                CEBMB  => '1',

                -- Test/BIST mode selects and BIST clock: unused
                AWT    => '0',
                BIST   => '0',
                CLKM   => '0',

                QA     => q_lo_a(b),
                QB     => q_lo_b(b)
            );

        macro_hi : TSDN65LPA2048X16M8M
            generic map (
                N => MACRO_N,
                W => MACRO_W,
                M => MACRO_M
            )
            port map (
                -- Port A: data channel, read-write with per-bit write mask
                AA     => addr_a,
                DA     => dat_i(31 downto 16),
                BWEBA  => bweb_hi,
                WEBA   => web_a,
                CEBA   => ceb_a(b),
                CLKA   => clk_i,

                -- Port B: instruction channel, read-only
                AB     => addr_b,
                DB     => DATA_ZERO,
                BWEBB  => BWEB_NONE,
                WEBB   => '1',
                CEBB   => ceb_b(b),
                CLKB   => clk_i,

                -- BIST port A: unused, held inactive
                AMA    => ADDR_ZERO,
                DMA    => DATA_ZERO,
                BWEBMA => BWEB_NONE,
                WEBMA  => '1',
                CEBMA  => '1',

                -- BIST port B: unused, held inactive
                AMB    => ADDR_ZERO,
                DMB    => DATA_ZERO,
                BWEBMB => BWEB_NONE,
                WEBMB  => '1',
                CEBMB  => '1',

                -- Test/BIST mode selects and BIST clock: unused
                AWT    => '0',
                BIST   => '0',
                CLKM   => '0',

                QA     => q_hi_a(b),
                QB     => q_hi_b(b)
            );

    end generate macros;

    -- Deselected macros hold their outputs, so the read mux must follow the
    -- bank that was actually enabled on the previous edge.
    sel_proc : process (clk_i)
    begin
        if rising_edge(clk_i) then
            if a_rd = '1' then
                sel_a <= bank_a;
            end if;
            if ram_req_b = '1' then
                sel_b <= bank_b;
            end if;
        end if;
    end process sel_proc;

    ack_proc : process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg   <= '0';
                ack_reg_b <= '0';
            else
                ack_reg   <= ram_req;
                ack_reg_b <= ram_req_b;
            end if;
        end if;
    end process ack_proc;

    ack_o   <= ack_reg;
    ack_b_o <= ack_reg_b;

    dat_o   <= q_hi_a(sel_a) & q_lo_a(sel_a);
    dat_b_o <= q_hi_b(sel_b) & q_lo_b(sel_b);

end architecture rtl;
