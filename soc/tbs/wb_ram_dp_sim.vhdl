library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_tb_pkg.all;

entity wb_ram_dp_sim is
    generic (
        BITS : natural := 15
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;

        -- Port A: data channel (read-write, byte selects)
        dat_i   : in  std_logic_vector(31 downto 0);
        cyc_i   : in  std_logic;
        stb_i   : in  std_logic;
        we_i    : in  std_logic;
        sel_i   : in  std_logic_vector(3 downto 0);
        adr_i   : in  std_logic_vector(BITS-3 downto 0);
        ack_o   : out std_logic;
        dat_o   : out std_logic_vector(31 downto 0);

        -- Port B: instruction channel (read-only, full word)
        cyc_b_i : in  std_logic;
        stb_b_i : in  std_logic;
        adr_b_i : in  std_logic_vector(BITS-3 downto 0);
        ack_b_o : out std_logic;
        dat_b_o : out std_logic_vector(31 downto 0)
    );
end entity wb_ram_dp_sim;

architecture sim of wb_ram_dp_sim is

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

    signal ram_req   : std_logic;
    signal ack_reg   : std_logic;
    signal dat_reg   : std_logic_vector(31 downto 0);

    signal ram_req_b : std_logic;
    signal ack_reg_b : std_logic;
    signal dat_reg_b : std_logic_vector(31 downto 0);

begin

    ram_req   <= cyc_i   and stb_i;
    ram_req_b <= cyc_b_i and stb_b_i;

    ram_proc: process(clk_i)
        variable addr_a : integer range 0 to MEM_SIZE/4-1;
        variable addr_b : integer range 0 to MEM_SIZE/4-1;
    begin
        if rising_edge(clk_i) then
            addr_a := to_integer(unsigned(adr_i));
            addr_b := to_integer(unsigned(adr_b_i));

            -- Port A: write. One request is accepted per cycle, matching the
            -- unconditional ack below. Gating this on ack_reg = '0' -- as a
            -- classic slave would -- silently drops the second of two requests
            -- presented on consecutive cycles, while still acknowledging it.
            if ram_req = '1' then
                if we_i = '1' then
                    if sel_i(0) = '1' then
                        mem0(addr_a) <= dat_i(7 downto 0);
                    end if;
                    if sel_i(1) = '1' then
                        mem1(addr_a) <= dat_i(15 downto 8);
                    end if;
                    if sel_i(2) = '1' then
                        mem2(addr_a) <= dat_i(23 downto 16);
                    end if;
                    if sel_i(3) = '1' then
                        mem3(addr_a) <= dat_i(31 downto 24);
                    end if;
                end if;
            end if;

            -- Leitura contínua de ambas as portas
            dat_reg   <= mem3(addr_a) & mem2(addr_a) & mem1(addr_a) & mem0(addr_a);
            dat_reg_b <= mem3(addr_b) & mem2(addr_b) & mem1(addr_b) & mem0(addr_b);
        end if;
    end process ram_proc;

    ack_reg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg <= '0';
            else
                ack_reg <= ram_req;
            end if;
        end if;
    end process ack_reg_proc;

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

    ack_o   <= ack_reg;
    dat_o   <= dat_reg;
    ack_b_o <= ack_reg_b;
    dat_b_o <= dat_reg_b;

end architecture sim;
