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
        clk   : in  std_logic;
        rst   : in  std_logic;
        clk_o : out std_logic;
        rst_o : out std_logic
    );
end entity wb_syscon;

architecture rtl of wb_syscon is

    signal rst_sync : std_logic_vector(1 downto 0);

begin

    rst_sync_proc: process(clk, rst)
    begin
        if rst = '0' then
            rst_sync <= (others => '1');
        elsif rising_edge(clk) then
            rst_sync <= rst_sync(0) & '0';
        end if;
    end process rst_sync_proc;

    clk_o <= clk;
    rst_o <= rst_sync(1);

end architecture rtl;
