----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: dual-port SRAM macro interface
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity sram_dp is
    generic (
        ADDR_BITS : natural;
        DATA_BITS : natural;
        INIT_FILE : string  := "";
        INIT_BANK : natural := 0;
        INIT_HALF : natural := 0
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
end entity sram_dp;
