library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_pkg.all;
use work.leaf_soc_tb_pkg.all;
use work.uart_tb_pkg.all;

entity leaf_soc_tb is
    generic (
        PROGRAM : string
    );
end entity leaf_soc_tb;

architecture tb of leaf_soc_tb is

    signal clk : std_logic;
    signal rst : std_logic;
    signal rx  : std_logic;
    signal tx  : std_logic;



    signal uart_data : std_logic_vector(7 downto 0);

    signal clk_en : std_logic := '0';

begin

    uut: leaf_soc port map (
        clk => clk,
        rst => rst,
        rx  => rx,
        tx  => tx
    );

    clk <= not clk after (CLK_PERIOD/2) when clk_en = '1' else '0';

    uart_rx_proc: process
        type char_file is file of character;
        file out_file : char_file;
        variable rx_data : std_logic_vector(7 downto 0);
        variable char : character;
    begin
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

    test: process
    begin
        rst  <= '1';
        rx   <= '1';
        clk_en <= '1';
        wait until rising_edge(clk);

        rst <= '0';
        wait until rising_edge(clk);

        for i in 0 to 511 loop
            wait until rising_edge(clk);
        end loop;

        leaf_soc_send_program(rx, uart_data, PROGRAM);

        wait for 1 ms;

        wait until rising_edge(clk);
        clk_en <= '0';
        wait;
    end process test;

end architecture tb;
