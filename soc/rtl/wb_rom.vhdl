----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: ROM (bootloader) with wishbone interface
-- 2026
----------------------------------------------------------------------

library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_pkg.all;
use work.boot_pkg.all;

entity wb_rom is
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        cyc_i : in  std_logic;
        stb_i : in  std_logic;
        sel_i : in  std_logic_vector(3 downto 0);
        adr_i : in  std_logic_vector(ROM_ADDR_WIDTH-1 downto 2);
        ack_o : out std_logic;
        dat_o : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0)
    );
end entity wb_rom;

architecture rtl of wb_rom is

    signal rom_req : std_logic;

	signal ack_reg : std_logic;

	signal dat_reg : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

begin

    rom_req <= cyc_i and stb_i;

    ack_reg_proc: process(clk_i)
	begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg <= '0';
            elsif ack_reg = '1' then
                ack_reg <= '0';
            else
                ack_reg <= rom_req;
            end if;
        end if;
	end process ack_reg_proc;

    dat_reg_0_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                dat_reg(7  downto  0) <= (others => '0');
            elsif ack_reg = '0' and rom_req = '1' and sel_i(0) = '1' then
                dat_reg(7  downto  0) <= BOOT_DATA_0(to_integer(unsigned(adr_i)));
            end if;
        end if;
    end process dat_reg_0_proc;

    dat_reg_1_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                dat_reg(15 downto  8) <= (others => '0');
            elsif ack_reg = '0' and rom_req = '1' and sel_i(1) = '1' then
                dat_reg(15 downto  8) <= BOOT_DATA_1(to_integer(unsigned(adr_i)));
            end if;
        end if;
    end process dat_reg_1_proc;

    dat_reg_2_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                dat_reg(23 downto 16) <= (others => '0');
            elsif ack_reg = '0' and rom_req = '1' and sel_i(2) = '1' then
                dat_reg(23 downto 16) <= BOOT_DATA_2(to_integer(unsigned(adr_i)));
            end if;
        end if;
    end process dat_reg_2_proc;

    dat_reg_3_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                dat_reg(31 downto 24) <= (others => '0');
            elsif ack_reg = '0' and rom_req = '1' and sel_i(3) = '1' then
                dat_reg(31 downto 24) <= BOOT_DATA_3(to_integer(unsigned(adr_i)));
            end if;
        end if;
    end process dat_reg_3_proc;

    ack_o <= ack_reg;
    dat_o <= dat_reg;

end architecture rtl;
