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

    signal xip_ack_i : std_logic;
    signal xip_err_i : std_logic;
    signal xip_dat_i : std_logic_vector(31 downto 0);
    signal xip_cyc_o : std_logic;
    signal xip_stb_o : std_logic;
    signal xip_we_o  : std_logic;
    signal xip_sel_o : std_logic_vector(3  downto 0);
    signal xip_adr_o : std_logic_vector(23 downto 2);
    signal xip_dat_o : std_logic_vector(31 downto 0);

    signal uart_data : std_logic_vector(7 downto 0);

    signal clk_en : std_logic := '0';

begin

    uut: leaf_soc port map (
        clk       => clk,
        rst       => rst,
        rx        => rx,
        tx        => tx,
        xip_ack_i => xip_ack_i,
        xip_err_i => xip_err_i,
        xip_dat_i => xip_dat_i,
        xip_cyc_o => xip_cyc_o,
        xip_stb_o => xip_stb_o,
        xip_we_o  => xip_we_o,
        xip_sel_o => xip_sel_o,
        xip_adr_o => xip_adr_o,
        xip_dat_o => xip_dat_o
    );

    tb_xip_ctrl: xip_ctrl port map (
        clk   => clk,
        rst   => rst,
        cyc_i => xip_cyc_o,
        stb_i => xip_stb_o,
        we_i  => xip_we_o,
        sel_i => xip_sel_o,
        adr_i => xip_adr_o,
        dat_i => xip_dat_o,
        ack_o => xip_ack_i,
        err_o => xip_err_i,
        dat_o => xip_dat_i
    );

    clk <= not clk after (CLK_PERIOD/2) when clk_en = '1' else '0';

    uart_rx_proc: process
        variable rx_data : std_logic_vector(7 downto 0);
    begin
        rx_loop : loop
            uart_receive(tx, rx_data);
            uart_data <= rx_data;
        end loop;
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

        wait until rising_edge(clk);
        clk_en <= '0';
        wait;
    end process test;

end architecture tb;
