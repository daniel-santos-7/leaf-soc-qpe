-- Simulation flavour of wb_ram_dp_tsmc: the same wrapper and the same macro
-- array, with the macros preloaded from PROGRAM_FILE (work/program.bin) so the
-- testbench can keep taking the RAM_JUMP_CMD shortcut instead of uploading the
-- program over UART.  Counterpart of wb_ram_dp_sim for the behavioural RAM;
-- bound in place of wb_ram_dp by the leaf_soc_tb_tsmc configuration.
--
-- The preload itself is the configuration in wb_ram_dp_tsmc_cfg.vhdl, which this
-- architecture instantiates.  wb_ram_dp_tsmc knows nothing about any of it.

library IEEE;
use IEEE.std_logic_1164.all;

entity wb_ram_dp_tsmc_sim is
    generic (
        BITS : natural := 15
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;

        dat_i   : in  std_logic_vector(31 downto 0);
        cyc_i   : in  std_logic;
        stb_i   : in  std_logic;
        we_i    : in  std_logic;
        sel_i   : in  std_logic_vector(3 downto 0);
        adr_i   : in  std_logic_vector(BITS-3 downto 0);
        ack_o   : out std_logic;
        dat_o   : out std_logic_vector(31 downto 0);

        cyc_b_i : in  std_logic;
        stb_b_i : in  std_logic;
        adr_b_i : in  std_logic_vector(BITS-3 downto 0);
        ack_b_o : out std_logic;
        dat_b_o : out std_logic_vector(31 downto 0)
    );
end entity wb_ram_dp_tsmc_sim;

architecture sim of wb_ram_dp_tsmc_sim is
begin

    assert 2**BITS / 4 = 4 * 2048
        report "wb_ram_dp_tsmc_sim: wb_ram_dp_tsmc_preloaded spells out 4 banks, "
             & "but BITS = " & integer'image(BITS)
             & " asks for a different geometry; the preload would be incomplete"
        severity failure;

    ram : configuration work.wb_ram_dp_tsmc_preloaded
        generic map (
            BITS => BITS
        )
        port map (
            clk_i => clk_i,
            rst_i => rst_i,

            dat_i => dat_i,
            cyc_i => cyc_i,
            stb_i => stb_i,
            we_i  => we_i,
            sel_i => sel_i,
            adr_i => adr_i,
            ack_o => ack_o,
            dat_o => dat_o,

            cyc_b_i => cyc_b_i,
            stb_b_i => stb_b_i,
            adr_b_i => adr_b_i,
            ack_b_o => ack_b_o,
            dat_b_o => dat_b_o
        );

end architecture sim;
