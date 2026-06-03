library IEEE;
use IEEE.std_logic_1164.all;
use work.sig_gen_pkg.all;

package leaf_soc_pkg is

    constant SOC_ADDR_WIDTH : natural := 32;
    constant SOC_DATA_WIDTH : natural := 32;

    constant ROM_BASE_ADDR : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"00001000";
    constant IO0_BASE_ADDR : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"10000000";
    constant IO1_BASE_ADDR : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"10001000";
    constant XIP_BASE_ADDR : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"20000000";
    constant RAM_BASE_ADDR : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0) := x"80000000";

    constant ROM_ADDR_WIDTH : natural := 9;    -- 512 bytes
    constant IO0_ADDR_WIDTH : natural := 4;    -- 16 bytes (4 registers)
    constant IO1_ADDR_WIDTH : natural := 4;    -- 16 bytes (4 registers)
    constant XIP_ADDR_WIDTH : natural := 24;   -- 16 MB
    constant RAM_ADDR_WIDTH : natural := 16;   -- 64 KB

    constant OUT_RES_BITS : natural := 12;

    component wb_syscon is
        port (
            clk   : in  std_logic;
            rst   : in  std_logic;
            clk_o : out std_logic;
            rst_o : out std_logic
        );
    end component wb_syscon;

    component wb_ram is
        generic (
            BITS : natural := 8
        );
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            dat_i : in  std_logic_vector(31 downto 0);
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            sel_i : in  std_logic_vector(3  downto 0);
            adr_i : in  std_logic_vector(BITS-3 downto 0);
            ack_o : out std_logic;
            dat_o : out std_logic_vector(31 downto 0)
        );
    end component wb_ram;

    component wb_rom is
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            adr_i : in  std_logic_vector(ROM_ADDR_WIDTH-1 downto 2);
            ack_o : out std_logic;
            dat_o : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0)
        );
    end component wb_rom;

    component wb_intercon is
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
    end component wb_intercon;

    component leaf_soc is
        port (
            clk : in  std_logic;
            rst : in  std_logic;
            rx  : in  std_logic;
            tx  : out std_logic;
            sig : out std_logic_vector(OUT_RES_BITS-1 downto 0)
        );
    end component leaf_soc;

    component wgx_csrs is
        port (
            clk_i   : in  std_logic;
            rst_i   : in  std_logic;
            addr_i  : in  std_logic_vector(5 downto 0);
            wdata_i : in  std_logic_vector(31 downto 0);
            we_i    : in  std_logic;
            rdata_o : out std_logic_vector(31 downto 0);
            inc_o   : out std_logic_vector(31 downto 0);
            pha_o   : out std_logic_vector(31 downto 0);
            amp_o   : out std_logic_vector(OUT_RES_BITS-1 downto 0);
            we_o    : out std_logic
        );
    end component wgx_csrs;

end package leaf_soc_pkg;
