library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

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
    
    rst_sync_proc: process(clk)
    begin
        if rising_edge(clk) then
            rst_sync <= rst_sync(0) & not rst;
        end if;
    end process rst_sync_proc;

    clk_o <= clk;
    rst_o <= rst_sync(1);

end architecture rtl;