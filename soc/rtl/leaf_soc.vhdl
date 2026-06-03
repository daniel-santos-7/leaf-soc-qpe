----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: leaf system (SOC)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_pkg.all;
use work.leaf_soc_pkg.all;
use work.uart_pkg.all;

entity leaf_soc is
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        rx  : in  std_logic;
        tx  : out std_logic
    );
end entity leaf_soc;

architecture rtl of leaf_soc is

    signal soc_syscon_clk : std_logic;
    signal soc_syscon_rst : std_logic;

    signal soc_cpu_cyc : std_logic;
    signal soc_cpu_stb : std_logic;
    signal soc_cpu_we  : std_logic;
    signal soc_cpu_sel : std_logic_vector(3  downto 0);
    signal soc_cpu_adr : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_cpu_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_intercon_cpu_ack : std_logic;
    signal soc_intercon_cpu_err : std_logic;
    signal soc_intercon_io0_stb : std_logic;
    signal soc_intercon_io1_stb : std_logic;
    signal soc_intercon_rom_stb : std_logic;
    signal soc_intercon_ram_stb : std_logic;
    signal soc_intercon_xip_stb : std_logic;
    signal soc_intercon_io0_cyc : std_logic;
    signal soc_intercon_io1_cyc : std_logic;
    signal soc_intercon_rom_cyc : std_logic;
    signal soc_intercon_ram_cyc : std_logic;
    signal soc_intercon_xip_cyc : std_logic;
    signal soc_intercon_io0_we  : std_logic;
    signal soc_intercon_io1_we  : std_logic;
    signal soc_intercon_ram_we  : std_logic;
    signal soc_intercon_xip_we  : std_logic;
    signal soc_intercon_io0_sel : std_logic_vector(3 downto 0);
    signal soc_intercon_io1_sel : std_logic_vector(3 downto 0);
    signal soc_intercon_ram_sel : std_logic_vector(3 downto 0);
    signal soc_intercon_xip_sel : std_logic_vector(3 downto 0);
    signal soc_intercon_io0_adr : std_logic_vector(IO0_ADDR_WIDTH-1 downto 2);
    signal soc_intercon_io1_adr : std_logic_vector(IO0_ADDR_WIDTH-1 downto 2);
    signal soc_intercon_rom_adr : std_logic_vector(ROM_ADDR_WIDTH-1 downto 2);
    signal soc_intercon_ram_adr : std_logic_vector(RAM_ADDR_WIDTH-1 downto 2);
    signal soc_intercon_xip_adr : std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
    signal soc_intercon_cpu_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_intercon_io0_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_intercon_io1_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_intercon_ram_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_intercon_xip_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_rom_ack : std_logic;
    signal soc_rom_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_io0_ack : std_logic;
    signal soc_io0_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_io1_ack : std_logic;
    signal soc_io1_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_xip_ack : std_logic;
    signal soc_xip_err : std_logic;
    signal soc_xip_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_ram_ack : std_logic;
    signal soc_ram_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

begin

    soc_syscon: wb_syscon port map (
        clk   => clk,
        rst   => rst,
        clk_o => soc_syscon_clk,
        rst_o => soc_syscon_rst
    );

    soc_cpu: leaf generic map (
        RESET_ADDR => ROM_BASE_ADDR
    ) port map (
        clk_i     => soc_syscon_clk,
        rst_i     => soc_syscon_rst,
        ex_irq_i  => '0',
        sw_irq_i  => '0',
        tm_irq_i  => '0',
        ack_i     => soc_intercon_cpu_ack,
        err_i     => soc_intercon_cpu_err,
        dat_i     => soc_intercon_cpu_dat,
        cop_adr_o => open,
        cop_dat_o => open,
        cop_we_o  => open,
        cyc_o     => soc_cpu_cyc,
        stb_o     => soc_cpu_stb,
        we_o      => soc_cpu_we,
        sel_o     => soc_cpu_sel,
        adr_o     => soc_cpu_adr,
        dat_o     => soc_cpu_dat
    );

    soc_intercon: wb_intercon port map (
        cpu_cyc_i => soc_cpu_cyc,
        cpu_stb_i => soc_cpu_stb,
        cpu_we_i  => soc_cpu_we,
        cpu_sel_i => soc_cpu_sel,
        cpu_adr_i => soc_cpu_adr,
        cpu_dat_i => soc_cpu_dat,
        io0_ack_i => soc_io0_ack,
        io1_ack_i => soc_io1_ack,
        rom_ack_i => soc_rom_ack,
        ram_ack_i => soc_ram_ack,
        xip_ack_i => soc_xip_ack,
        xip_err_i => soc_xip_err,
        io0_dat_i => soc_io0_dat,
        io1_dat_i => soc_io1_dat,
        rom_dat_i => soc_rom_dat,
        ram_dat_i => soc_ram_dat,
        xip_dat_i => soc_xip_dat,
        cpu_ack_o => soc_intercon_cpu_ack,
        cpu_err_o => soc_intercon_cpu_err,
        io0_cyc_o => soc_intercon_io0_cyc,
        io1_cyc_o => soc_intercon_io1_cyc,
        rom_cyc_o => soc_intercon_rom_cyc,
        ram_cyc_o => soc_intercon_ram_cyc,
        xip_cyc_o => soc_intercon_xip_cyc,
        io0_stb_o => soc_intercon_io0_stb,
        io1_stb_o => soc_intercon_io1_stb,
        rom_stb_o => soc_intercon_rom_stb,
        ram_stb_o => soc_intercon_ram_stb,
        xip_stb_o => soc_intercon_xip_stb,
        io0_we_o  => soc_intercon_io0_we,
        io1_we_o  => soc_intercon_io1_we,
        ram_we_o  => soc_intercon_ram_we,
        xip_we_o  => soc_intercon_xip_we,
        io0_sel_o => soc_intercon_io0_sel,
        io1_sel_o => soc_intercon_io1_sel,
        ram_sel_o => soc_intercon_ram_sel,
        xip_sel_o => soc_intercon_xip_sel,
        io0_adr_o => soc_intercon_io0_adr,
        io1_adr_o => soc_intercon_io1_adr,
        rom_adr_o => soc_intercon_rom_adr,
        ram_adr_o => soc_intercon_ram_adr,
        xip_adr_o => soc_intercon_xip_adr,
        cpu_dat_o => soc_intercon_cpu_dat,
        io0_dat_o => soc_intercon_io0_dat,
        io1_dat_o => soc_intercon_io1_dat,
        ram_dat_o => soc_intercon_ram_dat,
        xip_dat_o => soc_intercon_xip_dat
    );

    soc_rom: wb_rom port map (
        clk_i => soc_syscon_clk,
        rst_i => soc_syscon_rst,
        cyc_i => soc_intercon_rom_cyc,
        stb_i => soc_intercon_rom_stb,
        adr_i => soc_intercon_rom_adr,
        ack_o => soc_rom_ack,
        dat_o => soc_rom_dat
    );

    soc_uart: uart_wbsl port map (
        clk_i => soc_syscon_clk,
        rst_i => soc_syscon_rst,
        dat_i => soc_intercon_io0_dat,
        cyc_i => soc_intercon_io0_cyc,
        stb_i => soc_intercon_io0_stb,
        we_i  => soc_intercon_io0_we,
        sel_i => soc_intercon_io0_sel,
        adr_i => soc_intercon_io0_adr,
        rx    => rx,
        ack_o => soc_io0_ack,
        dat_o => soc_io0_dat,
        tx    => tx
    );

    -- XIP not connected --
    soc_xip_ack <= '0';
    soc_xip_err <= '1';
    soc_xip_dat <= (others => '0');

    -- memory 64 kB --
    soc_ram: wb_ram generic map (
        BITS  => 16
    ) port map (
        clk_i => soc_syscon_clk,
        rst_i => soc_syscon_rst,
        dat_i => soc_intercon_ram_dat,
        cyc_i => soc_intercon_ram_cyc,
        stb_i => soc_intercon_ram_stb,
        we_i  => soc_intercon_ram_we,
        sel_i => soc_intercon_ram_sel,
        adr_i => soc_intercon_ram_adr,
        ack_o => soc_ram_ack,
        dat_o => soc_ram_dat
    );

end architecture rtl;
