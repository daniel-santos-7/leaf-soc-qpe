-- VHDL twin of the TSMC 65nm LP dual-port SRAM simulation model shipped as
-- ram.v (compiler tsmcn65lpdpsram_2006.09.01.d.200b, library
-- tsdn65lpa2048x16m8m, 2048 words x 16 bits, BIST interface).
--
-- Why this file exists: ram.v is Verilog and the whole SoC is VHDL, and GHDL
-- has no Verilog front end, so the vendor model cannot be elaborated into this
-- simulation.  This entity reproduces the vendor model's *functional* zero-delay
-- behaviour (the `+UNIT_DELAY` flavour) pin for pin, so the SoC can be simulated
-- against the same memory organisation that will be taped out.
--
-- Why it lives in tbs/ and not rtl/: it is a *model*, not a design.  The real
-- TSDN65LPA2048X16M8M is a hard macro -- a black box that the synthesis and P&R
-- tools take from the vendor library as .lib/.lef, never as RTL.  Only
-- wb_ram_dp_tsmc, the wrapper that instantiates it and does the banking, is
-- design source.  Nothing here is meant to be synthesised, and the file I/O in
-- init_array would not be anyway.
--
-- What it deliberately does NOT reproduce:
--
--   * the `specify` path delays (ckq/dq/bwq/...) and the $setuphold/$recrem
--     timing checks -- there is no timing annotation in this flow;
--   * the fault-injection hook (`+TSMC_INITIALIZE_FAULT`).
--
-- Everything else -- write-enable polarity, per-bit write masks, the "Q only
-- moves on a read cycle" rule, and the three contention cases that inject 'X'
-- -- is modelled.  soc/tbs/xcheck/ holds the equivalence bench that feeds this
-- and ram.v the same stimulus (GHDL and Icarus respectively) and diffs QA/QB
-- cycle by cycle; run `make -C soc/tbs/xcheck` after touching this file.
--
-- INIT_FILE/INIT_BANK/INIT_HALF mirror the vendor model's `cdeFileInit`
-- parameter (`+TSMC_INITIALIZE_MEM`): they let a testbench preload the array.
-- The file is a raw little-endian 32-bit image (work/program.bin); this
-- instance takes the half-word selected by INIT_HALF of every 32-bit word that
-- falls inside bank INIT_BANK.  With INIT_FILE = "" the array powers up 'X',
-- like the real macro.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity TSDN65LPA2048X16M8M is
    generic (
        N : natural := 16;          -- data bits
        W : natural := 2048;        -- words
        M : natural := 11;          -- address bits

        MES_ALL : string := "ON";   -- "OFF" silences the runtime warnings

        INIT_FILE : string  := "";
        INIT_BANK : natural := 0;
        INIT_HALF : natural := 0
    );
    port (
        -- Port A (functional)
        AA    : in  std_logic_vector(M-1 downto 0);
        DA    : in  std_logic_vector(N-1 downto 0);
        BWEBA : in  std_logic_vector(N-1 downto 0);
        WEBA  : in  std_logic;
        CEBA  : in  std_logic;
        CLKA  : in  std_logic;

        -- Port B (functional)
        AB    : in  std_logic_vector(M-1 downto 0);
        DB    : in  std_logic_vector(N-1 downto 0);
        BWEBB : in  std_logic_vector(N-1 downto 0);
        WEBB  : in  std_logic;
        CEBB  : in  std_logic;
        CLKB  : in  std_logic;

        -- Port A (BIST)
        AMA    : in  std_logic_vector(M-1 downto 0);
        DMA    : in  std_logic_vector(N-1 downto 0);
        BWEBMA : in  std_logic_vector(N-1 downto 0);
        WEBMA  : in  std_logic;
        CEBMA  : in  std_logic;

        -- Port B (BIST)
        AMB    : in  std_logic_vector(M-1 downto 0);
        DMB    : in  std_logic_vector(N-1 downto 0);
        BWEBMB : in  std_logic_vector(N-1 downto 0);
        WEBMB  : in  std_logic;
        CEBMB  : in  std_logic;

        AWT  : in  std_logic;       -- async write-through test mode
        BIST : in  std_logic;       -- selects the *M ports and CLKM
        CLKM : in  std_logic;

        QA : out std_logic_vector(N-1 downto 0);
        QB : out std_logic_vector(N-1 downto 0)
    );
end entity TSDN65LPA2048X16M8M;

architecture behavioral of TSDN65LPA2048X16M8M is

    type mem_t is array (0 to W-1) of std_logic_vector(N-1 downto 0);

    -- The vendor model starts the array at 'x'; when a preload file is given we
    -- zero-fill first so that the (shorter) program image leaves the rest of the
    -- RAM defined, matching wb_ram_dp_sim.
    impure function init_array return mem_t is
        type char_file is file of character;
        file     bin_file : char_file;
        variable status    : file_open_status;
        variable byte      : character;
        variable addr      : natural;
        variable word_idx  : natural;
        variable lane      : natural;
        variable first     : natural;
        variable result    : mem_t := (others => (others => 'X'));
    begin
        if INIT_FILE = "" then
            return result;
        end if;

        result := (others => (others => '0'));

        file_open(status, bin_file, INIT_FILE, read_mode);
        if status /= open_ok then
            return result;
        end if;

        first := INIT_BANK * W;
        addr  := 0;
        while not endfile(bin_file) loop
            read(bin_file, byte);
            word_idx := addr / 4;
            lane     := addr mod 4;
            if word_idx >= first and word_idx < first + W
               and lane / 2 = INIT_HALF then
                result(word_idx - first)(8*(lane mod 2) + 7 downto 8*(lane mod 2))
                    := std_logic_vector(to_unsigned(character'pos(byte), 8));
            end if;
            addr := addr + 1;
        end loop;
        file_close(bin_file);

        return result;
    end function init_array;

    function has_x (v : std_logic_vector) return boolean is
    begin
        for i in v'range loop
            if v(i) /= '0' and v(i) /= '1' then
                return true;
            end if;
        end loop;
        return false;
    end function has_x;

    function is_x (s : std_logic) return boolean is
    begin
        return s /= '0' and s /= '1';
    end function is_x;

    -- BIST muxes: with BIST asserted both ports are driven by the *M pins and
    -- clocked by CLKM.
    signal clk_a  : std_logic;
    signal clk_b  : std_logic;
    signal ceb_a  : std_logic;
    signal ceb_b  : std_logic;
    signal web_a  : std_logic;
    signal web_b  : std_logic;
    signal adr_a  : std_logic_vector(M-1 downto 0);
    signal adr_b  : std_logic_vector(M-1 downto 0);
    signal dat_a  : std_logic_vector(N-1 downto 0);
    signal dat_b  : std_logic_vector(N-1 downto 0);
    signal bweb_a : std_logic_vector(N-1 downto 0);
    signal bweb_b : std_logic_vector(N-1 downto 0);

    signal qa_reg : std_logic_vector(N-1 downto 0) := (others => 'X');
    signal qb_reg : std_logic_vector(N-1 downto 0) := (others => 'X');

begin

    clk_a  <= CLKM   when BIST = '1' else CLKA;
    clk_b  <= CLKM   when BIST = '1' else CLKB;
    ceb_a  <= CEBMA  when BIST = '1' else CEBA;
    ceb_b  <= CEBMB  when BIST = '1' else CEBB;
    web_a  <= WEBMA  when BIST = '1' else WEBA;
    web_b  <= WEBMB  when BIST = '1' else WEBB;
    adr_a  <= AMA    when BIST = '1' else AA;
    adr_b  <= AMB    when BIST = '1' else AB;
    dat_a  <= DMA    when BIST = '1' else DA;
    dat_b  <= DMB    when BIST = '1' else DB;
    bweb_a <= BWEBMA when BIST = '1' else BWEBA;
    bweb_b <= BWEBMB when BIST = '1' else BWEBB;

    -- AWT drives the write path straight to the outputs, bypassing the array.
    QA <= (dat_a xor bweb_a) when AWT = '1' else qa_reg;
    QB <= (dat_b xor bweb_b) when AWT = '1' else qb_reg;

    array_proc : process (clk_a, clk_b)

        variable mem : mem_t := init_array;

        variable a_edge, b_edge : boolean;
        variable a_rd,   b_rd   : boolean;
        variable a_wr,   b_wr   : boolean;
        variable a_bad,  b_bad  : boolean;   -- unusable control/address
        variable addr_a, addr_b : natural range 0 to W-1;
        variable qa_new, qb_new : std_logic_vector(N-1 downto 0);
        variable word           : std_logic_vector(N-1 downto 0);

        procedure warn (msg : in string) is
        begin
            if MES_ALL = "ON" and now /= 0 ns then
                report "TSDN65LPA2048X16M8M: " & msg severity warning;
            end if;
        end procedure warn;

    begin
        a_edge := rising_edge(clk_a);
        b_edge := rising_edge(clk_b);

        if a_edge or b_edge then

            a_rd := false; a_wr := false; a_bad := false; addr_a := 0;
            b_rd := false; b_wr := false; b_bad := false; addr_b := 0;

            -- ------------------------------------------------------------------
            -- Decode what each port is doing on this edge.
            -- ------------------------------------------------------------------
            if a_edge then
                if is_x(ceb_a) then
                    warn("CEBA unknown, port A outputs set to unknown");
                    a_bad := true;
                elsif ceb_a = '0' then
                    if is_x(web_a) then
                        warn("WEBA unknown, outputs set to unknown");
                        a_bad := true;
                    elsif has_x(adr_a) then
                        if web_a = '0' then
                            warn("write address AA unknown, entire array set to unknown");
                            mem := (others => (others => 'X'));
                        else
                            warn("read address AA unknown, port A outputs set to unknown");
                        end if;
                        a_bad := true;
                    else
                        addr_a := to_integer(unsigned(adr_a));
                        a_rd   := web_a = '1';
                        a_wr   := web_a = '0';
                    end if;
                end if;
            end if;

            if b_edge then
                if is_x(ceb_b) then
                    warn("CEBB unknown, port B outputs set to unknown");
                    b_bad := true;
                elsif ceb_b = '0' then
                    if is_x(web_b) then
                        warn("WEBB unknown, outputs set to unknown");
                        b_bad := true;
                    elsif has_x(adr_b) then
                        if web_b = '0' then
                            warn("write address AB unknown, entire array set to unknown");
                            mem := (others => (others => 'X'));
                        else
                            warn("read address AB unknown, port B outputs set to unknown");
                        end if;
                        b_bad := true;
                    else
                        addr_b := to_integer(unsigned(adr_b));
                        b_rd   := web_b = '1';
                        b_wr   := web_b = '0';
                    end if;
                end if;
            end if;

            -- ------------------------------------------------------------------
            -- Reads sample the array *before* this edge's writes land, and go
            -- unknown if the opposite port is writing the same word.
            -- ------------------------------------------------------------------
            qa_new := qa_reg;
            qb_new := qb_reg;

            if a_rd then
                qa_new := mem(addr_a);
            end if;
            if b_rd then
                qb_new := mem(addr_b);
            end if;

            -- The whole word goes unknown, not just the bits the writing port
            -- enabled.  That is what ram.v does: its contention check tests the
            -- *latched* mask bBWEBAL/bBWEBBL, which the model only ever assigns
            -- 1'b0 and never clears back to 1'b1 (ram.v:132-133, 1637, 1742,
            -- 1852, 1940, 2019, 2059).  The bits therefore sit at 'x' until
            -- their first write and at '0' forever after, so the per-bit test
            -- `!bBWEBxL[i] || bBWEBxL[i] === 1'bx` is always true.  Modelling the
            -- per-bit behaviour the datasheet implies would make this twin
            -- optimistic relative to any simulator actually running ram.v.
            if a_rd and b_wr and addr_a = addr_b then
                warn("READ/WRITE contention, port A outputs set to unknown");
                qa_new := (others => 'X');
            end if;

            if b_rd and a_wr and addr_b = addr_a then
                warn("READ/WRITE contention, port B outputs set to unknown");
                qb_new := (others => 'X');
            end if;

            -- ------------------------------------------------------------------
            -- Writes.  Both ports hitting the same word corrupt the bits that both
            -- of them enable.
            -- ------------------------------------------------------------------
            if a_wr and b_wr and addr_a = addr_b then
                warn("WRITE/WRITE contention, commonly enabled bits set to unknown");
                word := mem(addr_a);
                for i in 0 to N-1 loop
                    if bweb_a(i) /= '1' and bweb_b(i) /= '1' then
                        word(i) := 'X';
                    elsif bweb_a(i) = '0' then
                        word(i) := dat_a(i);
                    elsif bweb_a(i) /= '1' then
                        word(i) := 'X';
                    elsif bweb_b(i) = '0' then
                        word(i) := dat_b(i);
                    elsif bweb_b(i) /= '1' then
                        word(i) := 'X';
                    end if;
                end loop;
                mem(addr_a) := word;
            else
                if a_wr then
                    word := mem(addr_a);
                    for i in 0 to N-1 loop
                        if bweb_a(i) = '0' then
                            word(i) := dat_a(i);
                        elsif bweb_a(i) /= '1' then
                            word(i) := 'X';
                        end if;
                    end loop;
                    mem(addr_a) := word;
                end if;
                if b_wr then
                    word := mem(addr_b);
                    for i in 0 to N-1 loop
                        if bweb_b(i) = '0' then
                            word(i) := dat_b(i);
                        elsif bweb_b(i) /= '1' then
                            word(i) := 'X';
                        end if;
                    end loop;
                    mem(addr_b) := word;
                end if;
            end if;

            -- ------------------------------------------------------------------
            -- Q only moves on a read cycle (or when the control pins were unusable);
            -- a write cycle and a deselected port both hold the previous value.
            -- ------------------------------------------------------------------
            -- An unknown WEB on either port poisons *both* outputs in the vendor
            -- model, so that case is folded in here rather than per port.
            if (a_edge and ceb_a = '0' and is_x(web_a))
               or (b_edge and ceb_b = '0' and is_x(web_b)) then
                qa_reg <= (others => 'X');
                qb_reg <= (others => 'X');
            else
                if a_bad then
                    qa_reg <= (others => 'X');
                elsif a_rd then
                    qa_reg <= qa_new;
                end if;

                if b_bad then
                    qb_reg <= (others => 'X');
                elsif b_rd then
                    qb_reg <= qb_new;
                end if;
            end if;
        end if;

    end process array_proc;

end architecture behavioral;
