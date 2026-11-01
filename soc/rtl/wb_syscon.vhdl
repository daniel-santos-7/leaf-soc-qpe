----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: system controller (clock and reset)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity wb_syscon is
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        halt_i    : in  std_logic;
        clk_o     : out std_logic;
        sys_rst_o : out std_logic;
        cpu_rst_o : out std_logic
    );
end entity wb_syscon;

architecture rtl of wb_syscon is

    signal rst_sync    : std_logic_vector(1 downto 0);
    signal sys_rst_reg : std_logic;
    signal cpu_rst_reg : std_logic;

begin

    rst_sync_proc: process(clk, rst_n)
    begin
        if rst_n = '0' then
            rst_sync <= (others => '1');
        elsif rising_edge(clk) then
            rst_sync <= rst_sync(0) & '0';
        end if;
    end process rst_sync_proc;

    rst_proc: process(clk, rst_n)
    begin
        if rst_n = '0' then
            sys_rst_reg <= '1';
            cpu_rst_reg <= '1';
        elsif rising_edge(clk) then
            sys_rst_reg <= rst_sync(1);
            cpu_rst_reg <= rst_sync(1) or halt_i;
        end if;
    end process rst_proc;

    clk_o <= clk;
    sys_rst_o <= sys_rst_reg;
    cpu_rst_o <= cpu_rst_reg;

end architecture rtl;
