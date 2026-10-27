----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: DAC output stage (pulse samples or external data)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_soc_pkg.all;

entity dac_out is
    port (
        clk_i     : in  std_logic;
        rst_i     : in  std_logic;
        sig_i_i   : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_i   : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        active_i  : in  std_logic;
        dac_dat_i : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_i_o   : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o   : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        active_o  : out std_logic
    );
end entity dac_out;

architecture rtl of dac_out is

    signal sig_i_reg  : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sig_q_reg  : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal active_reg : std_logic;

begin

    out_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                sig_i_reg  <= (others => '0');
                sig_q_reg  <= (others => '0');
                active_reg <= '0';
            elsif active_i = '1' then
                sig_i_reg  <= sig_i_i;
                sig_q_reg  <= sig_q_i;
                active_reg <= '1';
            else
                sig_i_reg  <= dac_dat_i;
                sig_q_reg  <= dac_dat_i;
                active_reg <= '0';
            end if;
        end if;
    end process out_proc;

    sig_i_o  <= sig_i_reg;
    sig_q_o  <= sig_q_reg;
    active_o <= active_reg;

end architecture rtl;
