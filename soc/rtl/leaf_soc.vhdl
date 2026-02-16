----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: leaf system (SOC)
-- 2026
----------------------------------------------------------------------

library IEEE;
library work;
use IEEE.std_logic_1164.all;
use work.core_pkg.all;
use work.leaf_soc_pkg.all;
use work.uart_pkg.all;

entity leaf_soc is
    port (
        clk : in  std_logic;
        rst : in  std_logic;
        rx  : in  std_logic;
        tx  : out std_logic;
        dbg : out std_logic_vector(7 downto 0)
    );
end entity leaf_soc;

architecture arch of leaf_soc is

    signal sys_clk : std_logic;
    signal sys_rst : std_logic;

    signal soc_cpu_cyc : std_logic;
    signal soc_cpu_stb : std_logic;
    signal soc_cpu_we  : std_logic;
    signal soc_cpu_sel : std_logic_vector(3  downto 0);
    signal soc_cpu_adr : std_logic_vector(31 downto 0);
    signal soc_cpu_dat : std_logic_vector(31 downto 0);

    signal soc_wb_intercon_cpu_ack  : std_logic;
    signal soc_wb_intercon_cpu_err  : std_logic;
    signal soc_wb_intercon_uart_stb : std_logic;
    signal soc_wb_intercon_rom_stb  : std_logic;
    signal soc_wb_intercon_ram_stb  : std_logic;
    signal soc_wb_intercon_dbg_stb  : std_logic;
    signal soc_wb_intercon_uart_cyc : std_logic;
    signal soc_wb_intercon_rom_cyc  : std_logic;
    signal soc_wb_intercon_ram_cyc  : std_logic;
    signal soc_wb_intercon_dbg_cyc  : std_logic;
    signal soc_wb_intercon_uart_we  : std_logic;
    signal soc_wb_intercon_rom_we   : std_logic;
    signal soc_wb_intercon_ram_we   : std_logic;
    signal soc_wb_intercon_dbg_we   : std_logic;
    signal soc_wb_intercon_uart_sel : std_logic_vector(3 downto 0);
    signal soc_wb_intercon_rom_sel  : std_logic_vector(3 downto 0);
    signal soc_wb_intercon_ram_sel  : std_logic_vector(3 downto 0);
    signal soc_wb_intercon_dbg_sel  : std_logic_vector(3 downto 0);
    signal soc_wb_intercon_uart_adr : std_logic_vector(1 downto 0);
    signal soc_wb_intercon_rom_adr  : std_logic_vector(5 downto 0);
    signal soc_wb_intercon_ram_adr  : std_logic_vector(13 downto 0);
    signal soc_wb_intercon_dbg_adr  : std_logic_vector(31 downto 0);
    signal soc_wb_intercon_cpu_dat  : std_logic_vector(31 downto 0);
    signal soc_wb_intercon_uart_dat : std_logic_vector(31 downto 0);
    signal soc_wb_intercon_rom_dat  : std_logic_vector(31 downto 0);
    signal soc_wb_intercon_ram_dat  : std_logic_vector(31 downto 0);
    signal soc_wb_intercon_dbg_dat  : std_logic_vector(7  downto 0);

    signal soc_uart_ack : std_logic;
    signal soc_uart_dat : std_logic_vector(31 downto 0);

    signal soc_rom_ack : std_logic;
    signal soc_rom_dat : std_logic_vector(31 downto 0);

    signal soc_ram_ack : std_logic;
    signal soc_ram_dat : std_logic_vector(31 downto 0);

    signal soc_dbg_ack : std_logic;
    signal soc_dbg_dat : std_logic_vector(7 downto 0);
    
begin
    
    syscon: soc_syscon port map (
        clk   => clk,
        rst   => rst,
        clk_o => sys_clk,
        rst_o => sys_rst
    );

    soc_cpu: leaf generic map (
        RESET_ADDR => x"00000100"
    ) port map (
        clk_i  => sys_clk,
        rst_i  => sys_rst,
        ex_irq => '0',
        sw_irq => '0',
        tm_irq => '0',
        ack_i  => soc_wb_intercon_cpu_ack,
        err_i  => soc_wb_intercon_cpu_err,
        dat_i  => soc_wb_intercon_cpu_dat,
        cyc_o  => soc_cpu_cyc,
        stb_o  => soc_cpu_stb,
        we_o   => soc_cpu_we,
        sel_o  => soc_cpu_sel,
        adr_o  => soc_cpu_adr,
        dat_o  => soc_cpu_dat
    );

    soc_wb_intercon: wb_intercon port map (
        cpu_cyc_i  => soc_cpu_cyc,
        cpu_stb_i  => soc_cpu_stb,
        cpu_we_i   => soc_cpu_we,
        cpu_sel_i  => soc_cpu_sel,
        cpu_adr_i  => soc_cpu_adr,
        cpu_dat_i  => soc_cpu_dat,
        uart_ack_i => soc_uart_ack,
        rom_ack_i  => soc_rom_ack,
        ram_ack_i  => soc_ram_ack,
        dbg_ack_i  => soc_dbg_ack,
        uart_err_i => '0',
        rom_err_i  => '0',
        ram_err_i  => '0',
        dbg_err_i  => '0',
        uart_dat_i => soc_uart_dat,
        rom_dat_i  => soc_rom_dat,
        ram_dat_i  => soc_ram_dat,
        dbg_dat_i  => soc_dbg_dat,
        cpu_ack_o  => soc_wb_intercon_cpu_ack,
        cpu_err_o  => soc_wb_intercon_cpu_err,
        uart_cyc_o => soc_wb_intercon_uart_cyc,
        rom_cyc_o  => soc_wb_intercon_rom_cyc,
        ram_cyc_o  => soc_wb_intercon_ram_cyc,
        dbg_cyc_o  => soc_wb_intercon_dbg_cyc,
        uart_stb_o => soc_wb_intercon_uart_stb,
        rom_stb_o  => soc_wb_intercon_rom_stb,
        ram_stb_o  => soc_wb_intercon_ram_stb,
        dbg_stb_o  => soc_wb_intercon_dbg_stb,
        uart_we_o  => soc_wb_intercon_uart_we,
        rom_we_o   => soc_wb_intercon_rom_we,
        ram_we_o   => soc_wb_intercon_ram_we,
        dbg_we_o   => soc_wb_intercon_dbg_we,
        uart_sel_o => soc_wb_intercon_uart_sel,
        rom_sel_o  => soc_wb_intercon_rom_sel,
        ram_sel_o  => soc_wb_intercon_ram_sel,
        dbg_sel_o  => soc_wb_intercon_dbg_sel,
        uart_adr_o => soc_wb_intercon_uart_adr,
        rom_adr_o  => soc_wb_intercon_rom_adr,
        ram_adr_o  => soc_wb_intercon_ram_adr,
        dbg_adr_o  => soc_wb_intercon_dbg_adr,
        cpu_dat_o  => soc_wb_intercon_cpu_dat,
        uart_dat_o => soc_wb_intercon_uart_dat,
        rom_dat_o  => soc_wb_intercon_rom_dat,
        ram_dat_o  => soc_wb_intercon_ram_dat,
        dbg_dat_o  => soc_wb_intercon_dbg_dat
    );

    soc_uart: uart_wbsl port map (
        clk_i => sys_clk,
        rst_i => sys_rst,
        dat_i => soc_wb_intercon_uart_dat,
        cyc_i => soc_wb_intercon_uart_cyc,
        stb_i => soc_wb_intercon_uart_stb,
        we_i  => soc_wb_intercon_uart_we,
        sel_i => soc_wb_intercon_uart_sel,
        adr_i => soc_wb_intercon_uart_adr,     
        rx    => rx,
        ack_o => soc_uart_ack,
        dat_o => soc_uart_dat,
        tx    => tx
    );

    soc_rom: rom generic map (
        BITS  => 8
    ) port map (
        clk_i => sys_clk,
        rst_i => sys_rst,
        cyc_i => soc_wb_intercon_rom_cyc,
        stb_i => soc_wb_intercon_rom_stb,
        adr_i => soc_wb_intercon_rom_adr,
        ack_o => soc_rom_ack,
        dat_o => soc_rom_dat
    );

    -- memory 64 kB --
    soc_ram: ram generic map (
        BITS  => 16
    ) port map (
        clk_i => sys_clk,
        rst_i => sys_rst,
        dat_i => soc_wb_intercon_ram_dat,
        cyc_i => soc_wb_intercon_ram_cyc,
        stb_i => soc_wb_intercon_ram_stb,
        we_i  => soc_wb_intercon_ram_we,
        sel_i => soc_wb_intercon_ram_sel,
        adr_i => soc_wb_intercon_ram_adr,
        ack_o => soc_ram_ack,
        dat_o => soc_ram_dat
    );

    -- debug register --
    soc_dbg: debug_reg port map (
        clk_i => sys_clk,
        rst_i => sys_rst,
        dat_i => soc_wb_intercon_dbg_dat,
        cyc_i => soc_wb_intercon_dbg_cyc,
        stb_i => soc_wb_intercon_dbg_stb,
        we_i  => soc_wb_intercon_dbg_we,
        ack_o => soc_dbg_ack,
        dat_o => soc_dbg_dat
    );

    -- debug register output --
    dbg <= soc_dbg_dat;

end architecture arch;