----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: leaf system (SOC)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_soc_pkg.all;

entity wb_intercon is
    port (
        cpu_cyc_i : in   std_logic;
        cpu_stb_i : in   std_logic;
        cpu_we_i  : in   std_logic;
        cpu_sel_i : in   std_logic_vector(3  downto 0);
        cpu_adr_i : in   std_logic_vector(SOC_ADDR_WIDTH-1 downto 0);
        cpu_dat_i : in   std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        rom_ack_i : in   std_logic;
        io0_ack_i : in   std_logic;
        io1_ack_i : in   std_logic;
        xip_ack_i : in   std_logic;
        ram_ack_i : in   std_logic;
        xip_err_i : in   std_logic;
        rom_dat_i : in   std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io0_dat_i : in   std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io1_dat_i : in   std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        xip_dat_i : in   std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ram_dat_i : in   std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        cpu_ack_o : out  std_logic;
        cpu_err_o : out  std_logic;
        rom_cyc_o : out  std_logic;
        io0_cyc_o : out  std_logic;
        io1_cyc_o : out  std_logic;
        xip_cyc_o : out  std_logic;
        ram_cyc_o : out  std_logic;
        rom_stb_o : out  std_logic;
        io0_stb_o : out  std_logic;
        io1_stb_o : out  std_logic;
        xip_stb_o : out  std_logic;
        ram_stb_o : out  std_logic;
        io0_we_o  : out  std_logic;
        io1_we_o  : out  std_logic;
        xip_we_o  : out  std_logic;
        ram_we_o  : out  std_logic;
        io0_sel_o : out  std_logic_vector(3  downto 0);
        io1_sel_o : out  std_logic_vector(3  downto 0);
        xip_sel_o : out  std_logic_vector(3  downto 0);
        ram_sel_o : out  std_logic_vector(3  downto 0);
        rom_adr_o : out  std_logic_vector(ROM_ADDR_WIDTH-1 downto 2);
        io0_adr_o : out  std_logic_vector(IO0_ADDR_WIDTH-1 downto 2);
        io1_adr_o : out  std_logic_vector(IO1_ADDR_WIDTH-1 downto 2);
        xip_adr_o : out  std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
        ram_adr_o : out  std_logic_vector(RAM_ADDR_WIDTH-1 downto 2);
        cpu_dat_o : out  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io0_dat_o : out  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        io1_dat_o : out  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        xip_dat_o : out  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ram_dat_o : out  std_logic_vector(SOC_DATA_WIDTH-1 downto 0)
    );
end entity wb_intercon;

architecture rtl of wb_intercon is

    signal rom_sel : std_logic;
    signal io0_sel : std_logic;
    signal io1_sel : std_logic;
    signal xip_sel : std_logic;
    signal ram_sel : std_logic;

    signal sel_err : std_logic;

begin

    rom_sel <= '1' when cpu_adr_i(SOC_ADDR_WIDTH-1 downto ROM_ADDR_WIDTH) = ROM_BASE_ADDR(SOC_ADDR_WIDTH-1 downto ROM_ADDR_WIDTH) else '0';
    io0_sel <= '1' when cpu_adr_i(SOC_ADDR_WIDTH-1 downto IO0_ADDR_WIDTH) = IO0_BASE_ADDR(SOC_ADDR_WIDTH-1 downto IO0_ADDR_WIDTH) else '0';
    io1_sel <= '1' when cpu_adr_i(SOC_ADDR_WIDTH-1 downto IO1_ADDR_WIDTH) = IO1_BASE_ADDR(SOC_ADDR_WIDTH-1 downto IO1_ADDR_WIDTH) else '0';
    xip_sel <= '1' when cpu_adr_i(SOC_ADDR_WIDTH-1 downto XIP_ADDR_WIDTH) = XIP_BASE_ADDR(SOC_ADDR_WIDTH-1 downto XIP_ADDR_WIDTH) else '0';
    ram_sel <= '1' when cpu_adr_i(SOC_ADDR_WIDTH-1 downto RAM_ADDR_WIDTH) = RAM_BASE_ADDR(SOC_ADDR_WIDTH-1 downto RAM_ADDR_WIDTH) else '0';

    sel_err <= not (rom_sel or io0_sel or io1_sel or xip_sel or ram_sel);

    cpu_ack_o <= (rom_ack_i and rom_sel) or (io0_ack_i and io0_sel) or (io1_ack_i and io1_sel) or (xip_ack_i and xip_sel) or (ram_ack_i and ram_sel);
    cpu_err_o <= cpu_cyc_i and cpu_stb_i and sel_err;

    rom_cyc_o <= cpu_cyc_i;
    io0_cyc_o <= cpu_cyc_i;
    io1_cyc_o <= cpu_cyc_i;
    xip_cyc_o <= cpu_cyc_i;
    ram_cyc_o <= cpu_cyc_i;

    rom_stb_o <= cpu_stb_i and rom_sel;
    io0_stb_o <= cpu_stb_i and io0_sel;
    io1_stb_o <= cpu_stb_i and io1_sel;
    xip_stb_o <= cpu_stb_i and xip_sel;
    ram_stb_o <= cpu_stb_i and ram_sel;

    io0_we_o <= cpu_we_i;
    io1_we_o <= cpu_we_i;
    xip_we_o <= cpu_we_i;
    ram_we_o <= cpu_we_i;

    io0_sel_o <= cpu_sel_i;
    io1_sel_o <= cpu_sel_i;
    xip_sel_o <= cpu_sel_i;
    ram_sel_o <= cpu_sel_i;

    rom_adr_o <= cpu_adr_i(ROM_ADDR_WIDTH-1 downto 2);
    io0_adr_o <= cpu_adr_i(IO0_ADDR_WIDTH-1 downto 2);
    io1_adr_o <= cpu_adr_i(IO1_ADDR_WIDTH-1 downto 2);
    xip_adr_o <= cpu_adr_i(XIP_ADDR_WIDTH-1 downto 2);
    ram_adr_o <= cpu_adr_i(RAM_ADDR_WIDTH-1 downto 2);

    cpu_dat_o <= rom_dat_i when rom_sel = '1' else
                 io0_dat_i when io0_sel = '1' else
                 io1_dat_i when io1_sel = '1' else
                 ram_dat_i when ram_sel = '1' else
                 xip_dat_i when xip_sel = '1' else
                 (others => '0');
    io0_dat_o <= cpu_dat_i;
    io1_dat_o <= cpu_dat_i;
    xip_dat_o <= cpu_dat_i;
    ram_dat_o <= cpu_dat_i;

end architecture rtl;
