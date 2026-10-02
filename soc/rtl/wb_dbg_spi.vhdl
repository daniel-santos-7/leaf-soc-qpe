----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: SPI debug bridge (Wishbone MASTER)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_soc_pkg.all;

entity wb_dbg_spi is
    port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        spi_sck_i  : in  std_logic;
        spi_cs_n_i : in  std_logic;
        spi_mosi_i : in  std_logic;
        spi_miso_o : out std_logic;
        cyc_o      : out std_logic;
        stb_o      : out std_logic;
        we_o       : out std_logic;
        sel_o      : out std_logic_vector(3 downto 0);
        adr_o      : out std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
        dat_o      : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        dat_i      : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ack_i      : in  std_logic;
        err_i      : in  std_logic;
        stall_i    : in  std_logic;
        halt_o     : out std_logic;
        sig_src_o  : out std_logic;
        sig_i_o    : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o    : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity wb_dbg_spi;

architecture rtl of wb_dbg_spi is

    signal active   : std_logic;
    signal rx_data  : std_logic_vector(7 downto 0);
    signal rx_valid : std_logic;
    signal tx_data  : std_logic_vector(7 downto 0);
    signal tx_load  : std_logic;

begin

    u_spi: entity work.spi_slave port map (
        clk_i      => clk_i,
        rst_i      => rst_i,
        sck_i      => spi_sck_i,
        cs_n_i     => spi_cs_n_i,
        mosi_i     => spi_mosi_i,
        miso_o     => spi_miso_o,
        active_o   => active,
        rx_data_o  => rx_data,
        rx_valid_o => rx_valid,
        tx_data_i  => tx_data,
        tx_load_o  => tx_load
    );

    u_ctrl: entity work.wb_dbg_ctrl port map (
        clk_i      => clk_i,
        rst_i      => rst_i,
        active_i   => active,
        rx_data_i  => rx_data,
        rx_valid_i => rx_valid,
        tx_data_o  => tx_data,
        tx_load_i  => tx_load,
        cyc_o      => cyc_o,
        stb_o      => stb_o,
        we_o       => we_o,
        sel_o      => sel_o,
        adr_o      => adr_o,
        dat_o      => dat_o,
        dat_i      => dat_i,
        ack_i      => ack_i,
        err_i      => err_i,
        stall_i    => stall_i,
        halt_o     => halt_o,
        sig_src_o  => sig_src_o,
        sig_i_o    => sig_i_o,
        sig_q_o    => sig_q_o
    );

end architecture rtl;
