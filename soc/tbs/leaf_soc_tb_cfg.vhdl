-- Behavioural RAM (default): inferred array, preloaded from work/program.bin.
configuration leaf_soc_tb_sim of leaf_soc_tb is
    for tb
        for uut : leaf_soc
            use entity work.leaf_soc(rtl);
            for rtl
                for soc_ram : wb_ram_dp
                    use entity work.wb_ram_dp_sim(sim);
                end for;
            end for;
        end for;
    end for;
end configuration leaf_soc_tb_sim;
