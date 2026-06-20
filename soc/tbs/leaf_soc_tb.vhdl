library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_pkg.all;
use work.leaf_soc_tb_pkg.all;
use work.uart_tb_pkg.all;

entity leaf_soc_tb is
    generic (
        PROGRAM : string;
        SKIP_UART_LOAD : boolean := false;
        RUN_CYCLES : natural := 500000
    );
end entity leaf_soc_tb;

architecture tb of leaf_soc_tb is

    signal clk : std_logic;
    signal rst : std_logic;
    signal rx  : std_logic;
    signal tx  : std_logic;
    signal sig_i  : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sig_q  : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal active : std_logic;

    signal uart_data : std_logic_vector(7 downto 0);

    signal spi_clk : std_logic;
    signal spi_mosi : std_logic;
    signal spi_miso : std_logic;
    signal spi_cs_n : std_logic;

    signal clk_en : std_logic := '0';

begin

    uut: entity work.leaf_soc port map (
        clk      => clk,
        rst      => rst,
        rx       => rx,
        tx       => tx,
        sig_i    => sig_i,
        sig_q    => sig_q,
        active   => active,
        spi_clk  => spi_clk,
        spi_mosi => spi_mosi,
        spi_miso => spi_miso,
        spi_cs_n => spi_cs_n
    );

    u_spi_flash: entity work.spi_flash_model
        generic map (
            INIT_FILE => PROGRAM
        )
        port map (
            clk_i    => clk,
            spi_clk  => spi_clk,
            spi_mosi => spi_mosi,
            spi_miso => spi_miso,
            spi_cs_n => spi_cs_n
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

        if SKIP_UART_LOAD then
            report "RAM preloaded, sending RAM_JUMP_CMD...";
            uart_transmit(rx, x"4A");
            wait until uart_data = x"06" for 100 us;
            if uart_data = x"06" then
                report "ACK received after RAM_JUMP_CMD, program started!";
            else
                report "ERROR: No ACK after RAM_JUMP_CMD" severity failure;
            end if;
        else
            leaf_soc_send_program(rx, uart_data, PROGRAM);
        end if;

        for i in 0 to RUN_CYCLES-1 loop
            wait until rising_edge(clk);
        end loop;

        clk_en <= '0';
        wait;
    end process test;

end architecture tb;
