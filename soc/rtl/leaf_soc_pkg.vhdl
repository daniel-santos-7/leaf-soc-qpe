----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: SoC package (memory map and components)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

package leaf_soc_pkg is

    constant SOC_ADDR_WIDTH : natural := 32;
    constant SOC_DATA_WIDTH : natural := 32;

    constant ROM_BASE_ADDR  : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"00001000";
    constant IO0_BASE_ADDR  : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"10000000";
    constant IO1_BASE_ADDR  : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"10001000";
    constant IO2_BASE_ADDR  : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"10002000";
    constant XIP_BASE_ADDR  : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"20000000";
    constant RAM0_BASE_ADDR : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"80000000";
    constant RAM1_BASE_ADDR : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"90000000";

    constant ROM_ADDR_WIDTH  : natural := 9;
    constant IO0_ADDR_WIDTH  : natural := 4;
    constant IO1_ADDR_WIDTH  : natural := 5;
    constant IO2_ADDR_WIDTH  : natural := 6;
    constant XIP_ADDR_WIDTH  : natural := 24;
    constant RAM0_ADDR_WIDTH : natural := 15;
    constant RAM1_ADDR_WIDTH : natural := 10;

    constant OUT_RES_BITS : natural := work.sine_lut_pkg.OUT_RES_BITS;

    constant GPIO_WIDTH : natural := 8;

    constant XIP_SCK_DIV        : positive := 1;
    constant XIP_CS_HIGH_CYCLES : positive := 2;
    constant XIP_FRAME_BITS     : positive := 64;

    constant SPI_WIDTH    : positive := 64;
    constant SPI_CNT_BITS : positive := 7;

    constant DBG_ID         : std_logic_vector(SOC_DATA_WIDTH-1 downto 0) := x"4C454146";
    constant DBG_FRAME_BITS : positive := 64;

    component wb_ram_dp is
        generic (
            BITS : natural := 15
        );
        port (
            clk_i   : in  std_logic;
            rst_i   : in  std_logic;
            dat_a_i : in  std_logic_vector(31 downto 0);
            cyc_a_i : in  std_logic;
            stb_a_i : in  std_logic;
            we_a_i  : in  std_logic;
            sel_a_i : in  std_logic_vector(3 downto 0);
            adr_a_i : in  std_logic_vector(BITS-3 downto 0);
            ack_a_o : out std_logic;
            dat_a_o : out std_logic_vector(31 downto 0);
            cyc_b_i : in  std_logic;
            stb_b_i : in  std_logic;
            adr_b_i : in  std_logic_vector(BITS-3 downto 0);
            ack_b_o : out std_logic;
            dat_b_o : out std_logic_vector(31 downto 0)
        );
    end component wb_ram_dp;

    component sram_dp is
        generic (
            ADDR_BITS : natural;
            DATA_BITS : natural
        );
        port (
            clk_a   : in  std_logic;
            en_a    : in  std_logic;
            we_a    : in  std_logic;
            wmask_a : in  std_logic_vector(DATA_BITS-1 downto 0);
            addr_a  : in  std_logic_vector(ADDR_BITS-1 downto 0);
            d_a     : in  std_logic_vector(DATA_BITS-1 downto 0);
            q_a     : out std_logic_vector(DATA_BITS-1 downto 0);
            clk_b   : in  std_logic;
            en_b    : in  std_logic;
            we_b    : in  std_logic;
            wmask_b : in  std_logic_vector(DATA_BITS-1 downto 0);
            addr_b  : in  std_logic_vector(ADDR_BITS-1 downto 0);
            d_b     : in  std_logic_vector(DATA_BITS-1 downto 0);
            q_b     : out std_logic_vector(DATA_BITS-1 downto 0)
        );
    end component sram_dp;

    component leaf_soc is
        generic (
            WGEN_IF_COP : boolean := true
        );
        port (
            clk     : in  std_logic;
            rst_n   : in  std_logic;
            rx      : in  std_logic;
            tx      : out std_logic;
            sig_i   : out std_logic_vector(OUT_RES_BITS-1 downto 0);
            sig_q   : out std_logic_vector(OUT_RES_BITS-1 downto 0);
            active  : out std_logic;
            sclk_i  : in  std_logic;
            sclk_o  : out std_logic;
            sclk_oe : out std_logic;
            cs_n_i  : in  std_logic;
            cs_n_o  : out std_logic;
            cs_n_oe : out std_logic;
            mosi_i  : in  std_logic;
            mosi_o  : out std_logic;
            mosi_oe : out std_logic;
            miso_i  : in  std_logic;
            miso_o  : out std_logic;
            miso_oe : out std_logic;
            dbg     : in  std_logic;
            gpio_i  : in  std_logic_vector(GPIO_WIDTH-1 downto 0);
            gpio_o  : out std_logic_vector(GPIO_WIDTH-1 downto 0);
            gpio_oe : out std_logic_vector(GPIO_WIDTH-1 downto 0);
            dac_dat : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
            dac_sel : in  std_logic
        );
    end component leaf_soc;

end package leaf_soc_pkg;
