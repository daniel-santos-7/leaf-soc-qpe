----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: ROM (bootloader) with wishbone interface
-- 2026
----------------------------------------------------------------------

library IEEE;
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

    assert (2 ** adr_i'length = BOOT_DATA'length) report "ROM: The bootloader and ROM memory sizes must be the same." severity failure;

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

    dat_reg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if ack_reg = '0' and rom_req = '1' then
                dat_reg <= BOOT_DATA(to_integer(unsigned(adr_i)));
            end if;
        end if;
    end process dat_reg_proc;

    ack_o <= ack_reg;
    dat_o <= dat_reg;

end architecture rtl;
