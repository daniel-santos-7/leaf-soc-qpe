----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: testbench configuration with the macro-based RAM
-- 2026
----------------------------------------------------------------------

configuration leaf_soc_tb_macro of leaf_soc_tb is
    for tb
        for uut : leaf_soc
            use entity work.leaf_soc(rtl);
            for rtl
                for soc_ram0 : wb_ram_dp
                    use entity work.wb_ram_dp_macro_sim(sim);
                end for;
            end for;
        end for;
    end for;
end configuration leaf_soc_tb_macro;
