----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: Wishbone interconnect (INTERCON)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_soc_pkg.all;

entity wb_intercon is
    port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        inst_cyc_i : in  std_logic;
        inst_stb_i : in  std_logic;
        inst_adr_i : in  std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
        inst_dat_o : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        inst_ack_o : out std_logic;
        inst_err_o : out std_logic;
        data_cyc_i : in  std_logic;
        data_stb_i : in  std_logic;
        data_we_i  : in  std_logic;
        data_sel_i : in  std_logic_vector(3 downto 0);
        data_adr_i : in  std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
        data_dat_i : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        data_dat_o : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        data_ack_o : out std_logic;
        data_err_o : out std_logic;
        rom_cyc_o  : out std_logic;
        rom_stb_o  : out std_logic;
        rom_adr_o  : out std_logic_vector(ROM_ADDR_WIDTH-1 downto 2);
        rom_ack_i  : in  std_logic;
        rom_dat_i  : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        xip_cyc_o  : out std_logic;
        xip_stb_o  : out std_logic;
        xip_we_o   : out std_logic;
        xip_sel_o  : out std_logic_vector(3 downto 0);
        xip_adr_o  : out std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
        xip_dat_o  : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        xip_ack_i  : in  std_logic;
        xip_err_i  : in  std_logic;
        xip_dat_i  : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ramb_cyc_o : out std_logic;
        ramb_stb_o : out std_logic;
        ramb_adr_o : out std_logic_vector(RAM_ADDR_WIDTH-1 downto 2);
        ramb_ack_i : in  std_logic;
        ramb_dat_i : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io0_cyc_o  : out std_logic;
        io0_stb_o  : out std_logic;
        io0_we_o   : out std_logic;
        io0_sel_o  : out std_logic_vector(3 downto 0);
        io0_adr_o  : out std_logic_vector(IO0_ADDR_WIDTH-1 downto 2);
        io0_dat_o  : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io0_ack_i  : in  std_logic;
        io0_dat_i  : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io1_cyc_o  : out std_logic;
        io1_stb_o  : out std_logic;
        io1_we_o   : out std_logic;
        io1_sel_o  : out std_logic_vector(3 downto 0);
        io1_adr_o  : out std_logic_vector(IO1_ADDR_WIDTH-1 downto 2);
        io1_dat_o  : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io1_ack_i  : in  std_logic;
        io1_dat_i  : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        rama_cyc_o : out std_logic;
        rama_stb_o : out std_logic;
        rama_we_o  : out std_logic;
        rama_sel_o : out std_logic_vector(3 downto 0);
        rama_adr_o : out std_logic_vector(RAM_ADDR_WIDTH-1 downto 2);
        rama_dat_o : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        rama_ack_i : in  std_logic;
        rama_dat_i : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0)
    );
end entity wb_intercon;

architecture rtl of wb_intercon is

begin

    inst_channel: wb_channel port map (
        clk_i     => clk_i,
        rst_i     => rst_i,
        cpu_cyc_i => inst_cyc_i,
        cpu_stb_i => inst_stb_i,
        cpu_we_i  => '0',
        cpu_sel_i => (others => '1'),
        cpu_adr_i => inst_adr_i,
        cpu_dat_i => (others => '0'),
        rom_ack_i => rom_ack_i,
        io0_ack_i => '0',
        io1_ack_i => '0',
        xip_ack_i => xip_ack_i,
        ram_ack_i => ramb_ack_i,
        rom_err_i => '0',
        io0_err_i => '1',
        io1_err_i => '1',
        xip_err_i => xip_err_i,
        ram_err_i => '0',
        rom_dat_i => rom_dat_i,
        io0_dat_i => (others => '0'),
        io1_dat_i => (others => '0'),
        xip_dat_i => xip_dat_i,
        ram_dat_i => ramb_dat_i,
        cpu_ack_o => inst_ack_o,
        cpu_err_o => inst_err_o,
        rom_cyc_o => rom_cyc_o,
        io0_cyc_o => open,
        io1_cyc_o => open,
        xip_cyc_o => xip_cyc_o,
        ram_cyc_o => ramb_cyc_o,
        rom_stb_o => rom_stb_o,
        io0_stb_o => open,
        io1_stb_o => open,
        xip_stb_o => xip_stb_o,
        ram_stb_o => ramb_stb_o,
        io0_we_o  => open,
        io1_we_o  => open,
        xip_we_o  => xip_we_o,
        ram_we_o  => open,
        io0_sel_o => open,
        io1_sel_o => open,
        xip_sel_o => xip_sel_o,
        ram_sel_o => open,
        rom_adr_o => rom_adr_o,
        io0_adr_o => open,
        io1_adr_o => open,
        xip_adr_o => xip_adr_o,
        ram_adr_o => ramb_adr_o,
        cpu_dat_o => inst_dat_o,
        io0_dat_o => open,
        io1_dat_o => open,
        xip_dat_o => xip_dat_o,
        ram_dat_o => open
    );

    data_channel: wb_channel port map (
        clk_i     => clk_i,
        rst_i     => rst_i,
        cpu_cyc_i => data_cyc_i,
        cpu_stb_i => data_stb_i,
        cpu_we_i  => data_we_i,
        cpu_sel_i => data_sel_i,
        cpu_adr_i => data_adr_i,
        cpu_dat_i => data_dat_i,
        rom_ack_i => '0',
        io0_ack_i => io0_ack_i,
        io1_ack_i => io1_ack_i,
        xip_ack_i => '0',
        ram_ack_i => rama_ack_i,
        rom_err_i => '1',
        io0_err_i => '0',
        io1_err_i => '0',
        xip_err_i => '1',
        ram_err_i => '0',
        rom_dat_i => (others => '0'),
        io0_dat_i => io0_dat_i,
        io1_dat_i => io1_dat_i,
        xip_dat_i => (others => '0'),
        ram_dat_i => rama_dat_i,
        cpu_ack_o => data_ack_o,
        cpu_err_o => data_err_o,
        rom_cyc_o => open,
        io0_cyc_o => io0_cyc_o,
        io1_cyc_o => io1_cyc_o,
        xip_cyc_o => open,
        ram_cyc_o => rama_cyc_o,
        rom_stb_o => open,
        io0_stb_o => io0_stb_o,
        io1_stb_o => io1_stb_o,
        xip_stb_o => open,
        ram_stb_o => rama_stb_o,
        io0_we_o  => io0_we_o,
        io1_we_o  => io1_we_o,
        xip_we_o  => open,
        ram_we_o  => rama_we_o,
        io0_sel_o => io0_sel_o,
        io1_sel_o => io1_sel_o,
        xip_sel_o => open,
        ram_sel_o => rama_sel_o,
        rom_adr_o => open,
        io0_adr_o => io0_adr_o,
        io1_adr_o => io1_adr_o,
        xip_adr_o => open,
        ram_adr_o => rama_adr_o,
        cpu_dat_o => data_dat_o,
        io0_dat_o => io0_dat_o,
        io1_dat_o => io1_dat_o,
        xip_dat_o => open,
        ram_dat_o => rama_dat_o
    );

end architecture rtl;
