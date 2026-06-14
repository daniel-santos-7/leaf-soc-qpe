library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_pkg.all;
use work.leaf_soc_tb_pkg.all;
use work.uart_tb_pkg.all;

entity leaf_soc_tb is
    generic (
        PROGRAM : string;
        RUN_CYCLES : natural := 500000
    );
end entity leaf_soc_tb;

architecture tb of leaf_soc_tb is

    signal clk : std_logic;
    signal rst : std_logic;
    signal rx  : std_logic;
    signal tx  : std_logic;
    signal sig : std_logic_vector(OUT_RES_BITS-1 downto 0);

    signal uart_data : std_logic_vector(7 downto 0);

    signal clk_en : std_logic := '0';

begin

    uut: leaf_soc port map (
        clk => clk,
        rst => rst,
        rx  => rx,
        tx  => tx,
        sig => sig
    );

    clk <= not clk after (CLK_PERIOD/2) when clk_en = '1' else '0';

    uart_rx_proc: process
        type char_file is file of character;
        file out_file : char_file;
        variable rx_data : std_logic_vector(7 downto 0);
        variable char : character;
    begin
        wait until rst = '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        file_open(out_file, "STD_OUTPUT", write_mode);
        rx_loop : loop
            uart_receive(tx, rx_data);
            uart_data <= rx_data;
            char := character'val(to_integer(unsigned(rx_data)));
            write(out_file, char);
        end loop;
        file_close(out_file);
        wait;
    end process uart_rx_proc;

    -- uart_tx_proc: process
    --     type char_file is file of character;
    --     file in_file : char_file;
    --     variable tx_data : std_logic_vector(7 downto 0);
    --     variable char : character;
    -- begin
    --     file_open(in_file, "STD_INPUT", read_mode);
    --     while not endfile(in_file) loop
    --         read(in_file, char);
    --         tx_data := std_logic_vector(to_unsigned(character'pos(char), 8));
    --         uart_transmit(rx, tx_data);
    --     end loop;
    --     file_close(in_file);
    --     wait;
    -- end process uart_tx_proc;

    test: process
    begin
        rst  <= '0';
        rx   <= '1';
        clk_en <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        rst <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        for i in 0 to 511 loop
            wait until rising_edge(clk);
        end loop;

        leaf_soc_send_program(rx, uart_data, PROGRAM);

        for i in 0 to RUN_CYCLES-1 loop
            wait until rising_edge(clk);
        end loop;

        clk_en <= '0';
        wait;
    end process test;

end architecture tb;
