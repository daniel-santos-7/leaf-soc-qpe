----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: SPI port sharing (XIP master, debug slave)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_soc_pkg.all;

entity spi_mux is
    port (
        clk_i          : in  std_logic;
        rst_i          : in  std_logic;
        dbg_i          : in  std_logic;
        spi_role_ack_i : in  std_logic;
        spi_tx_ready_i : in  std_logic;
        spi_rx_valid_i : in  std_logic;
        xip_tx_valid_i : in  std_logic;
        xip_tx_data_i  : in  std_logic_vector(SPI_WIDTH-1 downto 0);
        dbg_tx_valid_i : in  std_logic;
        dbg_tx_data_i  : in  std_logic_vector(SPI_WIDTH-1 downto 0);
        dbg_rx_ready_i : in  std_logic;
        spi_role_req_o : out std_logic;
        spi_tx_valid_o : out std_logic;
        spi_tx_data_o  : out std_logic_vector(SPI_WIDTH-1 downto 0);
        spi_rx_ready_o : out std_logic;
        xip_dis_o      : out std_logic;
        xip_tx_ready_o : out std_logic;
        xip_rx_valid_o : out std_logic;
        dbg_tx_ready_o : out std_logic;
        dbg_rx_valid_o : out std_logic
    );
end entity spi_mux;

architecture rtl of spi_mux is

    signal dbg_reg : std_logic_vector(1 downto 0);

begin

    sync_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                dbg_reg <= (others => '0');
            else
                dbg_reg <= dbg_reg(0) & dbg_i;
            end if;
        end if;
    end process sync_proc;

    spi_role_req_o <= not dbg_reg(1);
    spi_tx_valid_o <= xip_tx_valid_i when spi_role_ack_i = '1' else dbg_tx_valid_i;
    spi_tx_data_o  <= xip_tx_data_i  when spi_role_ack_i = '1' else dbg_tx_data_i;
    spi_rx_ready_o <= '1' when spi_role_ack_i = '1' else dbg_rx_ready_i;
    xip_dis_o      <= dbg_reg(1) or not spi_role_ack_i;
    xip_tx_ready_o <= spi_tx_ready_i and spi_role_ack_i;
    xip_rx_valid_o <= spi_rx_valid_i and spi_role_ack_i;
    dbg_tx_ready_o <= spi_tx_ready_i and not spi_role_ack_i;
    dbg_rx_valid_o <= spi_rx_valid_i and not spi_role_ack_i;

end architecture rtl;
