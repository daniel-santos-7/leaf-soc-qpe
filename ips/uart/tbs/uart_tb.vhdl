library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.uart_pkg.all;
use work.uart_tb_pkg.all;

entity uart_tb is
end entity uart_tb;

architecture tb of uart_tb is

    signal clk_i : std_logic;
    signal rst_i : std_logic;

    signal wb_bus : wishbone_bus_t;

    signal rx_i  : std_logic;
    signal tx_o  : std_logic;

    signal clk_en : std_logic := '0';

    signal uart_rx_data : std_logic_vector(7 downto 0);

    type byte_array is array (natural range <>) of std_logic_vector(7 downto 0);

    constant test_data : byte_array := (
        x"AA",
        x"55",
        x"CA",
        x"FE"
    );

begin

    uut: uart_wbsl port map (
        clk_i => clk_i,
        rst_i => rst_i,
        dat_i => wb_bus.dat_o,
        cyc_i => wb_bus.cyc_o,
        stb_i => wb_bus.stb_o,
        we_i  => wb_bus.we_o,
        sel_i => wb_bus.sel_o,
        adr_i => wb_bus.adr_o,
        rx    => rx_i,
        ack_o => wb_bus.ack_i,
        dat_o => wb_bus.dat_i,
        tx    => tx_o
    );

    clk_i <= not clk_i after (CLK_PERIOD/2) when clk_en = '1' else '0';

    uart_rx_proc: process
    begin
        clk_en <= '1';
        for i in test_data'range loop
            uart_expect(tx_o, test_data(i));
        end loop;
        clk_en <= '0';
        wait for 10 * CLK_PERIOD;
        wait;
     end process uart_rx_proc;

    test_proc: process
        variable wb_data : std_logic_vector(31 downto 0) := (others => '0');
    begin
        rst_i <= '1';

        wb_init(wb_bus);
        rx_i  <= '1';

        wait until rising_edge(clk_i);
        rst_i <= '0';

        wb_read(b"00", wb_data, clk_i, wb_bus);
        wb_read(b"01", wb_data, clk_i, wb_bus);
        wb_read(b"10", wb_data, clk_i, wb_bus);
        wb_read(b"11", wb_data, clk_i, wb_bus);

        wb_write(b"10", std_logic_vector(UART_115200_BAUD_RATE_DIVIDER), clk_i, wb_bus);

        for i in test_data'range loop
            uart_transmit(rx_i, test_data(i));
        end loop;

        for i in test_data'range loop
            wb_check(b"11", x"000000" & test_data(i), clk_i, wb_bus);
        end loop;

        for i in test_data'range loop
            wb_write(b"11", x"000000" & test_data(i), clk_i, wb_bus);
        end loop;

        wait;
    end process test_proc;

end architecture tb;
