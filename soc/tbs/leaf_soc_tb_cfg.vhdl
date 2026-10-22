configuration leaf_soc_tb_sim of leaf_soc_tb is
    for tb
        for uut : leaf_soc
            use entity work.leaf_soc(rtl);
            for rtl
                for ram1_gen
                    for soc_ram1 : wb_ram_dp
                        use entity work.wb_ram_dp_sim(sim);
                    end for;
                end for;
            end for;
        end for;
    end for;
end configuration leaf_soc_tb_sim;
