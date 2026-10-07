----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: macro-based RAM with simulation preload
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;

entity wb_ram_dp_macro_sim is
    generic (
        BITS : natural := 13
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
end entity wb_ram_dp_macro_sim;

architecture sim of wb_ram_dp_macro_sim is
begin

    assert BITS = 13
        report "wb_ram_dp_macro_sim: wb_ram_dp_macro_preloaded preloads exactly one 2048-word bank"
        severity failure;

    ram: configuration work.wb_ram_dp_macro_preloaded
        generic map (
            BITS => BITS
        )
        port map (
            clk_i   => clk_i,
            rst_i   => rst_i,
            dat_a_i => dat_a_i,
            cyc_a_i => cyc_a_i,
            stb_a_i => stb_a_i,
            we_a_i  => we_a_i,
            sel_a_i => sel_a_i,
            adr_a_i => adr_a_i,
            ack_a_o => ack_a_o,
            dat_a_o => dat_a_o,
            cyc_b_i => cyc_b_i,
            stb_b_i => stb_b_i,
            adr_b_i => adr_b_i,
            ack_b_o => ack_b_o,
            dat_b_o => dat_b_o
        );

end architecture sim;
