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
        dbg_cyc_i    : in  std_logic;
        dbg_stb_i    : in  std_logic;
        dbg_we_i     : in  std_logic;
        dbg_sel_i    : in  std_logic_vector(3 downto 0);
        dbg_adr_i    : in  std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
        dbg_dat_i    : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        dbg_dat_o    : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        dbg_ack_o    : out std_logic;
        dbg_err_o    : out std_logic;
        dbg_stall_o  : out std_logic;
        rom_cyc_o    : out std_logic;
        rom_stb_o    : out std_logic;
        rom_adr_o    : out std_logic_vector(ROM_ADDR_WIDTH-1 downto 2);
        rom_ack_i    : in  std_logic;
        rom_dat_i    : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        xip_cyc_o    : out std_logic;
        xip_stb_o    : out std_logic;
        xip_adr_o    : out std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
        xip_ack_i    : in  std_logic;
        xip_err_i    : in  std_logic;
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
        io2_cyc_o    : out std_logic;
        io2_stb_o    : out std_logic;
        io2_we_o     : out std_logic;
        io2_sel_o    : out std_logic_vector(3 downto 0);
        io2_adr_o    : out std_logic_vector(IO2_ADDR_WIDTH-1 downto 2);
        io2_dat_o    : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io2_ack_i    : in  std_logic;
        io2_dat_i    : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
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

    signal dch_cyc   : std_logic;
    signal dch_stb   : std_logic;
    signal dch_we    : std_logic;
    signal dch_sel   : std_logic_vector(3 downto 0);
    signal dch_adr   : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal dch_dat_w : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal dch_dat_r : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal dch_ack   : std_logic;
    signal dch_err   : std_logic;
    signal dch_stall : std_logic;

begin

    data_arbiter: entity work.wb_arbiter port map (
        clk_i      => clk_i,
        rst_i      => rst_i,
        m0_cyc_i   => data_cyc_i,
        m0_stb_i   => data_stb_i,
        m0_we_i    => data_we_i,
        m0_sel_i   => data_sel_i,
        m0_adr_i   => data_adr_i,
        m0_dat_i   => data_dat_i,
        m0_dat_o   => data_dat_o,
        m0_ack_o   => data_ack_o,
        m0_err_o   => data_err_o,
        m0_stall_o => data_stall_o,
        m1_cyc_i   => dbg_cyc_i,
        m1_stb_i   => dbg_stb_i,
        m1_we_i    => dbg_we_i,
        m1_sel_i   => dbg_sel_i,
        m1_adr_i   => dbg_adr_i,
        m1_dat_i   => dbg_dat_i,
        m1_dat_o   => dbg_dat_o,
        m1_ack_o   => dbg_ack_o,
        m1_err_o   => dbg_err_o,
        m1_stall_o => dbg_stall_o,
        s_cyc_o    => dch_cyc,
        s_stb_o    => dch_stb,
        s_we_o     => dch_we,
        s_sel_o    => dch_sel,
        s_adr_o    => dch_adr,
        s_dat_o    => dch_dat_w,
        s_dat_i    => dch_dat_r,
        s_ack_i    => dch_ack,
        s_err_i    => dch_err,
        s_stall_i  => dch_stall
    );

    inst_channel: entity work.wb_channel port map (
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
        io2_ack_i   => '0',
        xip_ack_i   => xip_ack_i,
        ram0_ack_i  => ram0b_ack_i,
        ram1_ack_i  => ram1b_ack_i,
        rom_err_i   => '0',
        io0_err_i   => '1',
        io1_err_i   => '1',
        io2_err_i   => '1',
        xip_err_i   => xip_err_i,
        ram0_err_i  => '0',
        ram1_err_i  => '0',
        rom_dat_i   => rom_dat_i,
        io0_dat_i   => (others => '0'),
        io1_dat_i   => (others => '0'),
        io2_dat_i   => (others => '0'),
        xip_dat_i   => xip_dat_i,
        ram0_dat_i  => ram0b_dat_i,
        ram1_dat_i  => ram1b_dat_i,
        cpu_ack_o   => inst_ack_o,
        cpu_err_o   => inst_err_o,
        cpu_stall_o => inst_stall_o,
        rom_cyc_o   => rom_cyc_o,
        io0_cyc_o   => open,
        io1_cyc_o   => open,
        io2_cyc_o   => open,
        xip_cyc_o   => xip_cyc_o,
        ram0_cyc_o  => ram0b_cyc_o,
        ram1_cyc_o  => ram1b_cyc_o,
        rom_stb_o   => rom_stb_o,
        io0_stb_o   => open,
        io1_stb_o   => open,
        io2_stb_o   => open,
        xip_stb_o   => xip_stb_o,
        ram0_stb_o  => ram0b_stb_o,
        ram1_stb_o  => ram1b_stb_o,
        io0_we_o    => open,
        io1_we_o    => open,
        io2_we_o    => open,
        xip_we_o    => open,
        ram0_we_o   => open,
        ram1_we_o   => open,
        io0_sel_o   => open,
        io1_sel_o   => open,
        io2_sel_o   => open,
        xip_sel_o   => open,
        ram0_sel_o  => open,
        ram1_sel_o  => open,
        rom_adr_o   => rom_adr_o,
        io0_adr_o   => open,
        io1_adr_o   => open,
        io2_adr_o   => open,
        xip_adr_o   => xip_adr_o,
        ram0_adr_o  => ram0b_adr_o,
        ram1_adr_o  => ram1b_adr_o,
        cpu_dat_o   => inst_dat_o,
        io0_dat_o   => open,
        io1_dat_o   => open,
        io2_dat_o   => open,
        xip_dat_o   => open,
        ram0_dat_o  => open,
        ram1_dat_o  => open
    );

    data_channel: entity work.wb_channel port map (
        clk_i       => clk_i,
        rst_i       => rst_i,
        cpu_cyc_i   => dch_cyc,
        cpu_stb_i   => dch_stb,
        cpu_we_i    => dch_we,
        cpu_sel_i   => dch_sel,
        cpu_adr_i   => dch_adr,
        cpu_dat_i   => dch_dat_w,
        rom_ack_i   => '0',
        io0_ack_i   => io0_ack_i,
        io1_ack_i   => io1_ack_i,
        io2_ack_i   => io2_ack_i,
        xip_ack_i   => '0',
        ram0_ack_i  => ram0a_ack_i,
        ram1_ack_i  => ram1a_ack_i,
        rom_err_i   => '1',
        io0_err_i   => '0',
        io1_err_i   => io1_err_i,
        io2_err_i   => '0',
        xip_err_i   => '1',
        ram0_err_i  => '0',
        ram1_err_i  => '0',
        rom_dat_i   => (others => '0'),
        io0_dat_i   => io0_dat_i,
        io1_dat_i   => io1_dat_i,
        io2_dat_i   => io2_dat_i,
        xip_dat_i   => (others => '0'),
        ram0_dat_i  => ram0a_dat_i,
        ram1_dat_i  => ram1a_dat_i,
        cpu_ack_o   => dch_ack,
        cpu_err_o   => dch_err,
        cpu_stall_o => dch_stall,
        rom_cyc_o   => open,
        io0_cyc_o   => io0_cyc_o,
        io1_cyc_o   => io1_cyc_o,
        io2_cyc_o   => io2_cyc_o,
        xip_cyc_o   => open,
        ram0_cyc_o  => ram0a_cyc_o,
        ram1_cyc_o  => ram1a_cyc_o,
        rom_stb_o   => open,
        io0_stb_o   => io0_stb_o,
        io1_stb_o   => io1_stb_o,
        io2_stb_o   => io2_stb_o,
        xip_stb_o   => open,
        ram0_stb_o  => ram0a_stb_o,
        ram1_stb_o  => ram1a_stb_o,
        io0_we_o    => io0_we_o,
        io1_we_o    => io1_we_o,
        io2_we_o    => io2_we_o,
        xip_we_o    => open,
        ram0_we_o   => ram0a_we_o,
        ram1_we_o   => ram1a_we_o,
        io0_sel_o   => io0_sel_o,
        io1_sel_o   => io1_sel_o,
        io2_sel_o   => io2_sel_o,
        xip_sel_o   => open,
        ram0_sel_o  => ram0a_sel_o,
        ram1_sel_o  => ram1a_sel_o,
        rom_adr_o   => open,
        io0_adr_o   => io0_adr_o,
        io1_adr_o   => io1_adr_o,
        io2_adr_o   => io2_adr_o,
        xip_adr_o   => open,
        ram0_adr_o  => ram0a_adr_o,
        ram1_adr_o  => ram1a_adr_o,
        cpu_dat_o   => dch_dat_r,
        io0_dat_o   => io0_dat_o,
        io1_dat_o   => io1_dat_o,
        io2_dat_o   => io2_dat_o,
        xip_dat_o   => open,
        ram0_dat_o  => ram0a_dat_o,
        ram1_dat_o  => ram1a_dat_o
    );

end architecture rtl;
