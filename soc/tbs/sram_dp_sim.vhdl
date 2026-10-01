----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: dual-port SRAM macro simulation model
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

architecture sim of sram_dp is

    constant WORDS : natural := 2**ADDR_BITS;
    constant BYTES : natural := DATA_BITS / 8;

    subtype word_t is std_logic_vector(DATA_BITS-1 downto 0);
    type mem_t is array (0 to WORDS-1) of word_t;

    constant WORD_X : word_t := (others => 'X');

    signal q_reg_a : word_t := WORD_X;
    signal q_reg_b : word_t := WORD_X;

    impure function init_mem return mem_t is
        type char_file_t is file of character;
        file     f      : char_file_t;
        variable status : file_open_status;
        variable c      : character;
        variable pos    : natural := 0;
        variable word   : natural;
        variable lane   : natural;
        variable mem    : mem_t := (others => WORD_X);
    begin
        if INIT_FILE = "" then
            return mem;
        end if;
        mem := (others => (others => '0'));
        file_open(status, f, INIT_FILE, read_mode);
        if status /= open_ok then
            return mem;
        end if;
        while not endfile(f) loop
            read(f, c);
            word := pos / (2*BYTES);
            lane := pos mod (2*BYTES);
            if word / WORDS = INIT_BANK and lane / BYTES = INIT_HALF then
                mem(word mod WORDS)(8*(lane mod BYTES)+7 downto 8*(lane mod BYTES)) :=
                    std_logic_vector(to_unsigned(character'pos(c), 8));
            end if;
            pos := pos + 1;
        end loop;
        file_close(f);
        return mem;
    end function init_mem;

begin

    assert DATA_BITS mod 8 = 0
        report "sram_dp(sim): DATA_BITS must be a whole number of bytes"
        severity failure;

    mem_proc: process(clk_a, clk_b)
        variable mem      : mem_t := init_mem;
        variable edge_a   : boolean;
        variable edge_b   : boolean;
        variable rd_a     : boolean;
        variable rd_b     : boolean;
        variable wr_a     : boolean;
        variable wr_b     : boolean;
        variable bad_a    : boolean;
        variable bad_b    : boolean;
        variable ia       : natural range 0 to WORDS-1;
        variable ib       : natural range 0 to WORDS-1;
        variable qa       : word_t;
        variable qb       : word_t;
    begin
        edge_a := rising_edge(clk_a);
        edge_b := rising_edge(clk_b);
        rd_a := false; wr_a := false; bad_a := false; ia := 0;
        rd_b := false; wr_b := false; bad_b := false; ib := 0;

        if edge_a and en_a /= '0' then
            if en_a /= '1' or Is_X(we_a) or Is_X(addr_a) then
                bad_a := true;
            else
                ia   := to_integer(unsigned(addr_a));
                rd_a := we_a = '0';
                wr_a := we_a = '1';
            end if;
        end if;

        if edge_b and en_b /= '0' then
            if en_b /= '1' or Is_X(we_b) or Is_X(addr_b) then
                bad_b := true;
            else
                ib   := to_integer(unsigned(addr_b));
                rd_b := we_b = '0';
                wr_b := we_b = '1';
            end if;
        end if;

        if (rd_a and wr_b and ia = ib) or (rd_b and wr_a and ia = ib) then
            report "sram_dp(sim): " & mem_proc'path_name & " reads and writes word " &
                   integer'image(ia) & " on its two ports in the same cycle; the read returns X"
                severity warning;
        end if;

        if wr_a and wr_b and ia = ib then
            report "sram_dp(sim): " & mem_proc'path_name & " writes word " &
                   integer'image(ia) & " on both ports in the same cycle; the bits both enable become X"
                severity warning;
        end if;

        if rd_a then
            qa := mem(ia);
            if wr_b and ib = ia then
                qa := WORD_X;
            end if;
        end if;

        if rd_b then
            qb := mem(ib);
            if wr_a and ia = ib then
                qb := WORD_X;
            end if;
        end if;

        if wr_a then
            for i in 0 to DATA_BITS-1 loop
                if wmask_a(i) = '1' then
                    if wr_b and ib = ia and wmask_b(i) /= '0' then
                        mem(ia)(i) := 'X';
                    else
                        mem(ia)(i) := d_a(i);
                    end if;
                elsif wmask_a(i) /= '0' then
                    mem(ia)(i) := 'X';
                end if;
            end loop;
        end if;

        if wr_b then
            for i in 0 to DATA_BITS-1 loop
                if wmask_b(i) = '1' then
                    if wr_a and ia = ib and wmask_a(i) /= '0' then
                        mem(ib)(i) := 'X';
                    else
                        mem(ib)(i) := d_b(i);
                    end if;
                elsif wmask_b(i) /= '0' then
                    mem(ib)(i) := 'X';
                end if;
            end loop;
        end if;

        if bad_a then
            q_reg_a <= WORD_X;
        elsif rd_a then
            q_reg_a <= qa;
        end if;

        if bad_b then
            q_reg_b <= WORD_X;
        elsif rd_b then
            q_reg_b <= qb;
        end if;
    end process mem_proc;

    q_a <= q_reg_a;
    q_b <= q_reg_b;

end architecture sim;
