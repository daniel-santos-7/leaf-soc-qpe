-- Simulation flavour of wb_ram_dp_tsmc: the same wrapper and the same macro
-- array, with the macros preloaded from PROGRAM_FILE (work/program.bin) so the
-- testbench can keep taking the RAM_JUMP_CMD shortcut instead of uploading the
-- program over UART.  This is the counterpart of wb_ram_dp_sim for the
-- behavioural RAM, and is bound in place of wb_ram_dp by the leaf_soc_tb_tsmc
-- configuration.
--
-- All of the preload lives here.  wb_ram_dp_tsmc itself knows nothing about it:
-- it declares the macro as a component carrying only the vendor's N/W/M, and the
-- configuration below rebinds each of those component instances to the
-- simulation model's entity, this time associating the INIT_FILE/INIT_BANK/
-- INIT_HALF generics that only the model has.  A binding indication with a
-- generic map and no port map keeps the default port association, so nothing
-- about the wiring is restated.
--
-- Each macro holds one half-word of one bank, so the slice a given instance owns
-- is (INIT_BANK, INIT_HALF); see tsdn65lpa2048x16m8m.vhdl for how the raw image
-- is cut up.

library IEEE;
use IEEE.std_logic_1164.all;

use work.leaf_soc_tb_pkg.all;

-- Spelling out the four banks is the price of doing this in a configuration:
-- INIT_BANK differs per instance and a configuration has no loop.  It therefore
-- pins the geometry to 32 KB / 2048-word macros; wb_ram_dp_tsmc_sim asserts that
-- below rather than letting a changed BITS silently preload only part of the RAM.
configuration wb_ram_dp_tsmc_preloaded of wb_ram_dp_tsmc is
    for rtl
        for macros(0)
            for macro_lo : TSDN65LPA2048X16M8M
                use entity work.TSDN65LPA2048X16M8M(behavioral)
                    generic map (
                        N => N, W => W, M => M,
                        INIT_FILE => PROGRAM_FILE,
                        INIT_BANK => 0,
                        INIT_HALF => 0
                    );
            end for;
            for macro_hi : TSDN65LPA2048X16M8M
                use entity work.TSDN65LPA2048X16M8M(behavioral)
                    generic map (
                        N => N, W => W, M => M,
                        INIT_FILE => PROGRAM_FILE,
                        INIT_BANK => 0,
                        INIT_HALF => 1
                    );
            end for;
        end for;
        for macros(1)
            for macro_lo : TSDN65LPA2048X16M8M
                use entity work.TSDN65LPA2048X16M8M(behavioral)
                    generic map (
                        N => N, W => W, M => M,
                        INIT_FILE => PROGRAM_FILE,
                        INIT_BANK => 1,
                        INIT_HALF => 0
                    );
            end for;
            for macro_hi : TSDN65LPA2048X16M8M
                use entity work.TSDN65LPA2048X16M8M(behavioral)
                    generic map (
                        N => N, W => W, M => M,
                        INIT_FILE => PROGRAM_FILE,
                        INIT_BANK => 1,
                        INIT_HALF => 1
                    );
            end for;
        end for;
        for macros(2)
            for macro_lo : TSDN65LPA2048X16M8M
                use entity work.TSDN65LPA2048X16M8M(behavioral)
                    generic map (
                        N => N, W => W, M => M,
                        INIT_FILE => PROGRAM_FILE,
                        INIT_BANK => 2,
                        INIT_HALF => 0
                    );
            end for;
            for macro_hi : TSDN65LPA2048X16M8M
                use entity work.TSDN65LPA2048X16M8M(behavioral)
                    generic map (
                        N => N, W => W, M => M,
                        INIT_FILE => PROGRAM_FILE,
                        INIT_BANK => 2,
                        INIT_HALF => 1
                    );
            end for;
        end for;
        for macros(3)
            for macro_lo : TSDN65LPA2048X16M8M
                use entity work.TSDN65LPA2048X16M8M(behavioral)
                    generic map (
                        N => N, W => W, M => M,
                        INIT_FILE => PROGRAM_FILE,
                        INIT_BANK => 3,
                        INIT_HALF => 0
                    );
            end for;
            for macro_hi : TSDN65LPA2048X16M8M
                use entity work.TSDN65LPA2048X16M8M(behavioral)
                    generic map (
                        N => N, W => W, M => M,
                        INIT_FILE => PROGRAM_FILE,
                        INIT_BANK => 3,
                        INIT_HALF => 1
                    );
            end for;
        end for;
    end for;
end configuration wb_ram_dp_tsmc_preloaded;
