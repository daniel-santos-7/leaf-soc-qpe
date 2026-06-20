library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_tb_pkg.all;

entity wb_ram_sim is
    generic (
        BITS : natural := 16
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        dat_i : in  std_logic_vector(31 downto 0);
        cyc_i : in  std_logic;
        stb_i : in  std_logic;
        we_i  : in  std_logic;
        sel_i : in  std_logic_vector(3  downto 0);
        adr_i : in  std_logic_vector(BITS-3 downto 0);
        ack_o : out std_logic;
        dat_o : out std_logic_vector(31 downto 0)
    );
end entity wb_ram_sim;

architecture sim of wb_ram_sim is

    constant MEM_SIZE : natural := 2**BITS;

    subtype mem_array is byte_array_t(0 to MEM_SIZE/4-1);

    type mem_lanes_t is array (0 to 3) of mem_array;

    impure function init_from_pkg return mem_lanes_t is
        variable result : mem_lanes_t := (others => (others => (others => '0')));
    begin
        init_mem(PROGRAM_FILE, MEM_SIZE, result(0), result(1), result(2), result(3));
        return result;
    end function;

    constant init_data : mem_lanes_t := init_from_pkg;

    signal mem0 : mem_array := init_data(0);
    signal mem1 : mem_array := init_data(1);
    signal mem2 : mem_array := init_data(2);
    signal mem3 : mem_array := init_data(3);

    signal ram_req : std_logic;
    signal ack_reg : std_logic;
    signal dat_reg : std_logic_vector(31 downto 0);

begin

    ram_req <= cyc_i and stb_i;

    dat_reg_proc: process(clk_i)
        variable addr : integer range 0 to MEM_SIZE/4-1;
    begin
        if rising_edge(clk_i) then
            addr := to_integer(unsigned(adr_i));
            if ack_reg = '0' and ram_req = '1' then
                if we_i = '1' then
                    if sel_i(0) = '1' then
                        mem0(addr) <= dat_i(7 downto 0);
                    end if;
                    if sel_i(1) = '1' then
                        mem1(addr) <= dat_i(15 downto 8);
                    end if;
                    if sel_i(2) = '1' then
                        mem2(addr) <= dat_i(23 downto 16);
                    end if;
                    if sel_i(3) = '1' then
                        mem3(addr) <= dat_i(31 downto 24);
                    end if;
                end if;
                dat_reg <= mem3(addr) & mem2(addr) & mem1(addr) & mem0(addr);
            end if;
        end if;
    end process dat_reg_proc;

    ack_reg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg <= '0';
            elsif ack_reg = '1' then
                ack_reg <= '0';
            else
                ack_reg <= ram_req;
            end if;
        end if;
    end process ack_reg_proc;

    ack_o <= ack_reg;
    dat_o <= dat_reg;

end architecture sim;
