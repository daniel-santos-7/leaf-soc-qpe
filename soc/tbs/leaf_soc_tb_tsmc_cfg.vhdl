-- Kept in its own file on purpose.  With both testbench configurations in one
-- file, compiling it for the BEHAV top also compiled leaf_soc_tb_tsmc, which
-- dragged wb_ram_dp_tsmc_sim into the link; `ghdl -m` then did not analyse the
-- configuration that its architecture instantiates -- that unit is not in the
-- BEHAV top's dependency closure -- and the link failed on an undefined
-- work__wb_ram_dp_tsmc_preloaded.  One top per file keeps the closures disjoint.

-- TSMC RAM: the same SoC with the 32 KB built out of eight
-- TSDN65LPA2048X16M8M macros.  Selected from the root Makefile with RAM=TSMC.
configuration leaf_soc_tb_tsmc of leaf_soc_tb is
    for tb
        for uut : leaf_soc
            use entity work.leaf_soc(rtl);
            for rtl
                for soc_ram : wb_ram_dp
                    use entity work.wb_ram_dp_tsmc_sim(sim);
                end for;
            end for;
        end for;
    end for;
end configuration leaf_soc_tb_tsmc;
