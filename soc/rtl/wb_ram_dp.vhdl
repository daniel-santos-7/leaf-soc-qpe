library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity wb_ram_dp is
    generic (
        BITS : natural := 15
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;

        -- Port A: data channel (read-write, byte selects)
        dat_a_i : in  std_logic_vector(31 downto 0);
        cyc_a_i : in  std_logic;
        stb_a_i : in  std_logic;
        we_a_i  : in  std_logic;
        sel_a_i : in  std_logic_vector(3 downto 0);
        adr_a_i : in  std_logic_vector(BITS-3 downto 0);
        ack_a_o : out std_logic;
        dat_a_o : out std_logic_vector(31 downto 0);

        -- Port B: instruction channel (read-only, full word)
        cyc_b_i : in  std_logic;
        stb_b_i : in  std_logic;
        adr_b_i : in  std_logic_vector(BITS-3 downto 0);
        ack_b_o : out std_logic;
        dat_b_o : out std_logic_vector(31 downto 0)
    );
end entity wb_ram_dp;

architecture rtl of wb_ram_dp is

    constant MEM_SIZE : natural := 2**BITS;

    type mem_array is array (0 to MEM_SIZE/4-1) of std_logic_vector(7 downto 0);

    signal mem0 : mem_array;
    signal mem1 : mem_array;
    signal mem2 : mem_array;
    signal mem3 : mem_array;

    signal ram_req_a : std_logic;
    signal ack_reg_a : std_logic;
    signal dat_reg_a : std_logic_vector(31 downto 0);

    signal ram_req_b : std_logic;
    signal ack_reg_b : std_logic;
    signal dat_reg_b : std_logic_vector(31 downto 0);

begin

    ram_req_a <= cyc_a_i and stb_a_i;
    ram_req_b <= cyc_b_i and stb_b_i;

    ram_proc: process(clk_i)
        variable addr_a : integer range 0 to MEM_SIZE/4-1;
        variable addr_b : integer range 0 to MEM_SIZE/4-1;
    begin
        if rising_edge(clk_i) then
            addr_a := to_integer(unsigned(adr_a_i));
            addr_b := to_integer(unsigned(adr_b_i));

            -- Port A: write. One request is accepted per cycle, matching the
            -- unconditional ack below. Gating this on ack_reg_a = '0' -- as a
            -- classic slave would -- silently drops the second of two requests
            -- presented on consecutive cycles, while still acknowledging it.
            if ram_req_a = '1' then
                if we_a_i = '1' then
                    if sel_a_i(0) = '1' then
                        mem0(addr_a) <= dat_a_i(7 downto 0);
                    end if;
                    if sel_a_i(1) = '1' then
                        mem1(addr_a) <= dat_a_i(15 downto 8);
                    end if;
                    if sel_a_i(2) = '1' then
                        mem2(addr_a) <= dat_a_i(23 downto 16);
                    end if;
                    if sel_a_i(3) = '1' then
                        mem3(addr_a) <= dat_a_i(31 downto 24);
                    end if;
                end if;
            end if;

            -- Leitura contínua de ambas as portas
            dat_reg_a <= mem3(addr_a) & mem2(addr_a) & mem1(addr_a) & mem0(addr_a);
            dat_reg_b <= mem3(addr_b) & mem2(addr_b) & mem1(addr_b) & mem0(addr_b);
        end if;
    end process ram_proc;

    ack_reg_a_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg_a <= '0';
            else
                ack_reg_a <= ram_req_a;
            end if;
        end if;
    end process ack_reg_a_proc;

    ack_reg_b_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg_b <= '0';
            else
                ack_reg_b <= ram_req_b;
            end if;
        end if;
    end process ack_reg_b_proc;

    ack_a_o <= ack_reg_a;
    dat_a_o <= dat_reg_a;
    ack_b_o <= ack_reg_b;
    dat_b_o <= dat_reg_b;

end architecture rtl;
