-- Candidate run: drives the VHDL twin (soc/tbs/tsdn65lpa2048x16m8m.vhdl) with
-- the same stimulus.txt and the same 10 ns cycle/sampling scheme as tb_macro.v,
-- so out_vhdl.txt can be diffed line for line against out_verilog.txt.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use std.textio.all;

entity tb_macro is
end entity tb_macro;

architecture bench of tb_macro is

    signal clk : std_logic := '0';

    signal aa, ab       : std_logic_vector(10 downto 0) := (others => '0');
    signal da, db       : std_logic_vector(15 downto 0) := (others => '0');
    signal bweba, bwebb : std_logic_vector(15 downto 0) := (others => '1');
    signal weba, webb   : std_logic := '1';
    signal ceba, cebb   : std_logic := '1';

    signal qa, qb : std_logic_vector(15 downto 0);

    constant ADDR_ZERO : std_logic_vector(10 downto 0) := (others => '0');
    constant DATA_ZERO : std_logic_vector(15 downto 0) := (others => '0');
    constant MASK_OFF  : std_logic_vector(15 downto 0) := (others => '1');

    -- Verilog's %b prints an unknown bit as 'x'; mirror that so the two files
    -- are byte-identical when the models agree.
    function to_vlog (v : std_logic_vector) return string is
        variable r : string(1 to v'length);
        variable i : natural := 1;
    begin
        for k in v'range loop
            case v(k) is
                when '0'    => r(i) := '0';
                when '1'    => r(i) := '1';
                when 'Z'    => r(i) := 'z';
                when others => r(i) := 'x';
            end case;
            i := i + 1;
        end loop;
        return r;
    end function to_vlog;

    function to_sl (v : integer) return std_logic is
    begin
        if v = 1 then
            return '1';
        else
            return '0';
        end if;
    end function to_sl;

begin

    dut : entity work.TSDN65LPA2048X16M8M
        generic map (
            MES_ALL => "OFF"
        )
        port map (
            AA => aa, DA => da, BWEBA => bweba, WEBA => weba, CEBA => ceba, CLKA => clk,
            AB => ab, DB => db, BWEBB => bwebb, WEBB => webb, CEBB => cebb, CLKB => clk,

            AMA => ADDR_ZERO, DMA => DATA_ZERO, BWEBMA => MASK_OFF,
            WEBMA => '1', CEBMA => '1',
            AMB => ADDR_ZERO, DMB => DATA_ZERO, BWEBMB => MASK_OFF,
            WEBMB => '1', CEBMB => '1',

            AWT => '0', BIST => '0', CLKM => '0',

            QA => qa, QB => qb
        );

    stimulus : process
        file     stim : text;
        file     outf : text;
        variable status : file_open_status;
        variable l_in   : line;
        variable l_out  : line;
        variable v      : integer;
        variable cycle  : natural := 0;
        variable ok     : boolean;
    begin
        file_open(status, stim, "stimulus.txt", read_mode);
        assert status = open_ok
            report "cannot open stimulus.txt" severity failure;
        file_open(outf, "out_vhdl.txt", write_mode);

        while not endfile(stim) loop
            readline(stim, l_in);
            if l_in'length > 0 then
                read(l_in, v, ok); exit when not ok;
                aa    <= std_logic_vector(to_unsigned(v, 11));
                read(l_in, v); da    <= std_logic_vector(to_unsigned(v, 16));
                read(l_in, v); bweba <= std_logic_vector(to_unsigned(v, 16));
                read(l_in, v); weba  <= to_sl(v);
                read(l_in, v); ceba  <= to_sl(v);
                read(l_in, v); ab    <= std_logic_vector(to_unsigned(v, 11));
                read(l_in, v); db    <= std_logic_vector(to_unsigned(v, 16));
                read(l_in, v); bwebb <= std_logic_vector(to_unsigned(v, 16));
                read(l_in, v); webb  <= to_sl(v);
                read(l_in, v); cebb  <= to_sl(v);

                wait for 5 ns; clk <= '1';
                wait for 4 ns;
                write(l_out, to_vlog(qa) & " " & to_vlog(qb));
                writeline(outf, l_out);
                wait for 1 ns; clk <= '0';
                cycle := cycle + 1;
            end if;
        end loop;

        file_close(outf);
        file_close(stim);
        report "tb_macro: " & integer'image(cycle) & " cycles written to out_vhdl.txt";
        wait;
    end process stimulus;

end architecture bench;
