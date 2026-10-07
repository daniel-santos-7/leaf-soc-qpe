----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: preloaded configuration of the macro-based RAM
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_soc_tb_pkg.all;

configuration wb_ram_dp_macro_preloaded of wb_ram_dp_macro is
    for rtl
        for macros(0)
            for macro_lo : sram_dp
                use entity work.sram_dp(sim)
                    generic map (
                        ADDR_BITS => ADDR_BITS,
                        DATA_BITS => DATA_BITS,
                        INIT_FILE => PROGRAM_FILE,
                        INIT_BANK => 0,
                        INIT_HALF => 0
                    );
            end for;
            for macro_hi : sram_dp
                use entity work.sram_dp(sim)
                    generic map (
                        ADDR_BITS => ADDR_BITS,
                        DATA_BITS => DATA_BITS,
                        INIT_FILE => PROGRAM_FILE,
                        INIT_BANK => 0,
                        INIT_HALF => 1
                    );
            end for;
        end for;
    end for;
end configuration wb_ram_dp_macro_preloaded;
