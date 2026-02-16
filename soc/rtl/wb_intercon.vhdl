----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: leaf system (SOC)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity wb_intercon is
    port (
        cpu_cyc_i  : in   std_logic;
        cpu_stb_i  : in   std_logic;
        cpu_we_i   : in   std_logic;
        cpu_sel_i  : in   std_logic_vector(3  downto 0);
        cpu_adr_i  : in   std_logic_vector(31 downto 0);
        cpu_dat_i  : in   std_logic_vector(31 downto 0);
        uart_ack_i : in   std_logic;
        rom_ack_i  : in   std_logic;
        ram_ack_i  : in   std_logic;
        dbg_ack_i  : in   std_logic;
        uart_err_i : in   std_logic;
        rom_err_i  : in   std_logic;
        ram_err_i  : in   std_logic;
        dbg_err_i  : in   std_logic;
        uart_dat_i : in   std_logic_vector(31 downto 0);
        rom_dat_i  : in   std_logic_vector(31 downto 0);
        ram_dat_i  : in   std_logic_vector(31 downto 0);
        dbg_dat_i  : in   std_logic_vector(7  downto 0);
        cpu_ack_o  : out  std_logic;
        cpu_err_o  : out  std_logic;
        uart_cyc_o : out  std_logic;
        rom_cyc_o  : out  std_logic;
        ram_cyc_o  : out  std_logic;
        dbg_cyc_o  : out  std_logic;
        uart_stb_o : out  std_logic;
        rom_stb_o  : out  std_logic;
        ram_stb_o  : out  std_logic;
        dbg_stb_o  : out  std_logic;
        uart_we_o  : out  std_logic;
        rom_we_o   : out  std_logic;
        ram_we_o   : out  std_logic;
        dbg_we_o   : out  std_logic;
        uart_sel_o : out  std_logic_vector(3  downto 0);
        rom_sel_o  : out  std_logic_vector(3  downto 0);
        ram_sel_o  : out  std_logic_vector(3  downto 0);
        dbg_sel_o  : out  std_logic_vector(3  downto 0);
        uart_adr_o : out  std_logic_vector(1  downto 0);
        ram_adr_o  : out  std_logic_vector(13 downto 0);
        rom_adr_o  : out  std_logic_vector(5  downto 0);
        dbg_adr_o  : out  std_logic_vector(31 downto 0);
        cpu_dat_o  : out  std_logic_vector(31 downto 0);
        uart_dat_o : out  std_logic_vector(31 downto 0);
        rom_dat_o  : out  std_logic_vector(31 downto 0);
        ram_dat_o  : out  std_logic_vector(31 downto 0);
        dbg_dat_o  : out  std_logic_vector(7  downto 0)
    );
end entity wb_intercon;

architecture rtl of wb_intercon is

    signal uart_acmp: std_logic;
    signal dbg_acmp : std_logic;
    signal rom_acmp : std_logic;
    signal ram_acmp : std_logic;

begin
    
    -- address docode --
    uart_acmp <= '1' when cpu_adr_i(31 downto  4) = x"0000000" else '0';
    dbg_acmp  <= '1' when cpu_adr_i(31 downto  4) = x"0000001" else '0';
    rom_acmp  <= '1' when cpu_adr_i(31 downto  8) = x"000001" else '0';
    ram_acmp  <= '1' when cpu_adr_i(31 downto 16) = x"0001" else '0';

    cpu_ack_o <= uart_ack_i or rom_ack_i or ram_ack_i or dbg_ack_i;
    cpu_err_o <= uart_err_i or rom_err_i or ram_err_i or dbg_err_i;

    uart_cyc_o <= cpu_cyc_i;
    rom_cyc_o  <= cpu_cyc_i;
    ram_cyc_o  <= cpu_cyc_i;
    dbg_cyc_o  <= cpu_cyc_i;
    
    uart_stb_o <= uart_acmp and cpu_stb_i;
    rom_stb_o  <= rom_acmp and cpu_stb_i;
    ram_stb_o  <= ram_acmp and cpu_stb_i;
    dbg_stb_o  <= dbg_acmp and cpu_stb_i;
    
    uart_we_o <= cpu_we_i;
    rom_we_o  <= cpu_we_i;
    ram_we_o  <= cpu_we_i;
    dbg_we_o  <= cpu_we_i;

    uart_sel_o <= cpu_sel_i;
    rom_sel_o  <= cpu_sel_i;
    ram_sel_o  <= cpu_sel_i;
    dbg_sel_o  <= cpu_sel_i;

    uart_adr_o <= cpu_adr_i(3  downto 2);
    rom_adr_o  <= cpu_adr_i(7  downto 2);
    ram_adr_o  <= cpu_adr_i(15 downto 2);
    dbg_adr_o  <= cpu_adr_i;

    cpu_dat_o  <= uart_dat_i when uart_acmp = '1' else rom_dat_i when rom_acmp = '1' else ram_dat_i when ram_acmp = '1' else  (31 downto 8 => '0') & dbg_dat_i when dbg_acmp = '1' else (others => '0');
    uart_dat_o <= cpu_dat_i;
    rom_dat_o  <= cpu_dat_i;
    ram_dat_o  <= cpu_dat_i;
    dbg_dat_o  <= cpu_dat_i(7 downto 0);

end architecture rtl;