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
        clk_i        : in  std_logic;
        rst_i        : in  std_logic;
        inst_cyc_i   : in  std_logic;
        inst_stb_i   : in  std_logic;
        inst_adr_i   : in  std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
        inst_dat_o   : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        inst_ack_o   : out std_logic;
        inst_err_o   : out std_logic;
        inst_stall_o : out std_logic;
        data_cyc_i   : in  std_logic;
        data_stb_i   : in  std_logic;
        data_we_i    : in  std_logic;
        data_sel_i   : in  std_logic_vector(3 downto 0);
        data_adr_i   : in  std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
        data_dat_i   : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        data_dat_o   : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        data_ack_o   : out std_logic;
        data_err_o   : out std_logic;
        data_stall_o : out std_logic;
        rom_cyc_o    : out std_logic;
        rom_stb_o    : out std_logic;
        rom_adr_o    : out std_logic_vector(ROM_ADDR_WIDTH-1 downto 2);
        rom_ack_i    : in  std_logic;
        rom_dat_i    : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        xip_cyc_o    : out std_logic;
        xip_stb_o    : out std_logic;
        xip_adr_o    : out std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
        xip_ack_i    : in  std_logic;
        xip_dat_i    : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ram0b_cyc_o  : out std_logic;
        ram0b_stb_o  : out std_logic;
        ram0b_adr_o  : out std_logic_vector(RAM0_ADDR_WIDTH-1 downto 2);
        ram0b_ack_i  : in  std_logic;
        ram0b_dat_i  : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ram1b_cyc_o  : out std_logic;
        ram1b_stb_o  : out std_logic;
        ram1b_adr_o  : out std_logic_vector(RAM1_ADDR_WIDTH-1 downto 2);
        ram1b_ack_i  : in  std_logic;
        ram1b_dat_i  : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io0_cyc_o    : out std_logic;
        io0_stb_o    : out std_logic;
        io0_we_o     : out std_logic;
        io0_sel_o    : out std_logic_vector(3 downto 0);
        io0_adr_o    : out std_logic_vector(IO0_ADDR_WIDTH-1 downto 2);
        io0_dat_o    : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io0_ack_i    : in  std_logic;
        io0_dat_i    : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io1_cyc_o    : out std_logic;
        io1_stb_o    : out std_logic;
        io1_we_o     : out std_logic;
        io1_sel_o    : out std_logic_vector(3 downto 0);
        io1_adr_o    : out std_logic_vector(IO1_ADDR_WIDTH-1 downto 2);
        io1_dat_o    : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io1_ack_i    : in  std_logic;
        io1_err_i    : in  std_logic;
        io1_dat_i    : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ram0a_cyc_o  : out std_logic;
        ram0a_stb_o  : out std_logic;
        ram0a_we_o   : out std_logic;
        ram0a_sel_o  : out std_logic_vector(3 downto 0);
        ram0a_adr_o  : out std_logic_vector(RAM0_ADDR_WIDTH-1 downto 2);
        ram0a_dat_o  : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ram0a_ack_i  : in  std_logic;
        ram0a_dat_i  : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ram1a_cyc_o  : out std_logic;
        ram1a_stb_o  : out std_logic;
        ram1a_we_o   : out std_logic;
        ram1a_sel_o  : out std_logic_vector(3 downto 0);
        ram1a_adr_o  : out std_logic_vector(RAM1_ADDR_WIDTH-1 downto 2);
        ram1a_dat_o  : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ram1a_ack_i  : in  std_logic;
        ram1a_dat_i  : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0)
    );
end entity wb_intercon;

architecture rtl of wb_intercon is

begin

    inst_channel: wb_channel port map (
        clk_i       => clk_i,
        rst_i       => rst_i,
        cpu_cyc_i   => inst_cyc_i,
        cpu_stb_i   => inst_stb_i,
        cpu_we_i    => '0',
        cpu_sel_i   => (others => '1'),
        cpu_adr_i   => inst_adr_i,
        cpu_dat_i   => (others => '0'),
        rom_ack_i   => rom_ack_i,
        io0_ack_i   => '0',
        io1_ack_i   => '0',
        xip_ack_i   => xip_ack_i,
        ram0_ack_i  => ram0b_ack_i,
        ram1_ack_i  => ram1b_ack_i,
        rom_err_i   => '0',
        io0_err_i   => '1',
        io1_err_i   => '1',
        xip_err_i   => '0',
        ram0_err_i  => '0',
        ram1_err_i  => '0',
        rom_dat_i   => rom_dat_i,
        io0_dat_i   => (others => '0'),
        io1_dat_i   => (others => '0'),
        xip_dat_i   => xip_dat_i,
        ram0_dat_i  => ram0b_dat_i,
        ram1_dat_i  => ram1b_dat_i,
        cpu_ack_o   => inst_ack_o,
        cpu_err_o   => inst_err_o,
        cpu_stall_o => inst_stall_o,
        rom_cyc_o   => rom_cyc_o,
        io0_cyc_o   => open,
        io1_cyc_o   => open,
        xip_cyc_o   => xip_cyc_o,
        ram0_cyc_o  => ram0b_cyc_o,
        ram1_cyc_o  => ram1b_cyc_o,
        rom_stb_o   => rom_stb_o,
        io0_stb_o   => open,
        io1_stb_o   => open,
        xip_stb_o   => xip_stb_o,
        ram0_stb_o  => ram0b_stb_o,
        ram1_stb_o  => ram1b_stb_o,
        io0_we_o    => open,
        io1_we_o    => open,
        xip_we_o    => open,
        ram0_we_o   => open,
        ram1_we_o   => open,
        io0_sel_o   => open,
        io1_sel_o   => open,
        xip_sel_o   => open,
        ram0_sel_o  => open,
        ram1_sel_o  => open,
        rom_adr_o   => rom_adr_o,
        io0_adr_o   => open,
        io1_adr_o   => open,
        xip_adr_o   => xip_adr_o,
        ram0_adr_o  => ram0b_adr_o,
        ram1_adr_o  => ram1b_adr_o,
        cpu_dat_o   => inst_dat_o,
        io0_dat_o   => open,
        io1_dat_o   => open,
        xip_dat_o   => open,
        ram0_dat_o  => open,
        ram1_dat_o  => open
    );

    data_channel: wb_channel port map (
        clk_i       => clk_i,
        rst_i       => rst_i,
        cpu_cyc_i   => data_cyc_i,
        cpu_stb_i   => data_stb_i,
        cpu_we_i    => data_we_i,
        cpu_sel_i   => data_sel_i,
        cpu_adr_i   => data_adr_i,
        cpu_dat_i   => data_dat_i,
        rom_ack_i   => '0',
        io0_ack_i   => io0_ack_i,
        io1_ack_i   => io1_ack_i,
        xip_ack_i   => '0',
        ram0_ack_i  => ram0a_ack_i,
        ram1_ack_i  => ram1a_ack_i,
        rom_err_i   => '1',
        io0_err_i   => '0',
        io1_err_i   => io1_err_i,
        xip_err_i   => '1',
        ram0_err_i  => '0',
        ram1_err_i  => '0',
        rom_dat_i   => (others => '0'),
        io0_dat_i   => io0_dat_i,
        io1_dat_i   => io1_dat_i,
        xip_dat_i   => (others => '0'),
        ram0_dat_i  => ram0a_dat_i,
        ram1_dat_i  => ram1a_dat_i,
        cpu_ack_o   => data_ack_o,
        cpu_err_o   => data_err_o,
        cpu_stall_o => data_stall_o,
        rom_cyc_o   => open,
        io0_cyc_o   => io0_cyc_o,
        io1_cyc_o   => io1_cyc_o,
        xip_cyc_o   => open,
        ram0_cyc_o  => ram0a_cyc_o,
        ram1_cyc_o  => ram1a_cyc_o,
        rom_stb_o   => open,
        io0_stb_o   => io0_stb_o,
        io1_stb_o   => io1_stb_o,
        xip_stb_o   => open,
        ram0_stb_o  => ram0a_stb_o,
        ram1_stb_o  => ram1a_stb_o,
        io0_we_o    => io0_we_o,
        io1_we_o    => io1_we_o,
        xip_we_o    => open,
        ram0_we_o   => ram0a_we_o,
        ram1_we_o   => ram1a_we_o,
        io0_sel_o   => io0_sel_o,
        io1_sel_o   => io1_sel_o,
        xip_sel_o   => open,
        ram0_sel_o  => ram0a_sel_o,
        ram1_sel_o  => ram1a_sel_o,
        rom_adr_o   => open,
        io0_adr_o   => io0_adr_o,
        io1_adr_o   => io1_adr_o,
        xip_adr_o   => open,
        ram0_adr_o  => ram0a_adr_o,
        ram1_adr_o  => ram1a_adr_o,
        cpu_dat_o   => data_dat_o,
        io0_dat_o   => io0_dat_o,
        io1_dat_o   => io1_dat_o,
        xip_dat_o   => open,
        ram0_dat_o  => ram0a_dat_o,
        ram1_dat_o  => ram1a_dat_o
    );

end architecture rtl;
