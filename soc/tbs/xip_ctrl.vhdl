library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_tb_pkg.all;

entity xip_ctrl is
    port (
        clk   : in  std_logic;
        rst   : in  std_logic;
        cyc_i : in  std_logic;
        stb_i : in  std_logic;
        we_i  : in  std_logic;
        sel_i : in  std_logic_vector(3  downto 0);
        adr_i : in  std_logic_vector(23 downto 2);
        dat_i : in  std_logic_vector(31 downto 0);
        ack_o : out std_logic;
        err_o : out std_logic;
        dat_o : out std_logic_vector(31 downto 0)
    );
end entity xip_ctrl;

architecture rtl of xip_ctrl is

    signal ack_reg : std_logic;

    signal addr : natural;

begin

    addr <= to_integer(unsigned(adr_i(23 downto 2)));

    process(clk, rst)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                ack_reg <= '0';
            else
                ack_reg <= cyc_i and stb_i and not ack_reg;
            end if;
        end if;
    end process;

    process(clk, rst)

        variable mem : byte_array_t(0 to 2**24 - 1);

    begin
        if rising_edge(clk) then
            if rst = '1' then
                mem := (others => (others => '0'));
                dat_o <= (others => '0');
            elsif cyc_i = '1' and stb_i = '1' and ack_reg = '0' then
                if we_i = '1' then
                    if sel_i(0) = '1' then
                        mem(addr + 0) := dat_i(7 downto 0);
                    end if;
                    if sel_i(1) = '1' then
                        mem(addr + 1) := dat_i(15 downto 8);
                    end if;
                    if sel_i(2) = '1' then
                        mem(addr + 2) := dat_i(23 downto 16);
                    end if;
                    if sel_i(3) = '1' then
                        mem(addr + 3) := dat_i(31 downto 24);
                    end if;
                else
                    if sel_i(0) = '1' then
                        dat_o(7 downto 0) <= mem(addr + 0);
                    end if;
                    if sel_i(1) = '1' then
                        dat_o(15 downto 8) <= mem(addr + 1);
                    end if;
                    if sel_i(2) = '1' then
                        dat_o(23 downto 16) <= mem(addr + 2);
                    end if;
                    if sel_i(3) = '1' then
                        dat_o(31 downto 24) <= mem(addr + 3);
                    end if;
                end if;
            end if;
        end if;
    end process;

    ack_o <= ack_reg;
    err_o <= '0';

end architecture rtl;
