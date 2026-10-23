----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: dual-port Wishbone RAM, inferred or built from SRAM macros
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_pkg.all;

entity wb_ram_dp is
    generic (
        BITS            : natural := 15;
        MACRO_ADDR_BITS : natural := 11
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;

        dat_a_i : in  std_logic_vector(31 downto 0);
        cyc_a_i : in  std_logic;
        stb_a_i : in  std_logic;
        we_a_i  : in  std_logic;
        sel_a_i : in  std_logic_vector(3 downto 0);
        adr_a_i : in  std_logic_vector(BITS-3 downto 0);
        ack_a_o   : out std_logic;
        stall_a_o : out std_logic;
        dat_a_o   : out std_logic_vector(31 downto 0);

        cyc_b_i : in  std_logic;
        stb_b_i : in  std_logic;
        adr_b_i : in  std_logic_vector(BITS-3 downto 0);
        ack_b_o   : out std_logic;
        stall_b_o : out std_logic;
        dat_b_o   : out std_logic_vector(31 downto 0)
    );
end entity wb_ram_dp;

architecture macro of wb_ram_dp is

    constant BANK_BITS : natural := BITS - 2 - MACRO_ADDR_BITS;
    constant BANKS     : natural := 2**BANK_BITS;

    subtype half_t is std_logic_vector(15 downto 0);
    type half_array_t is array (0 to BANKS-1) of half_t;

    constant HALF_ZERO : half_t := (others => '0');

    signal ram_req_a : std_logic;
    signal ram_req_b : std_logic;
    signal coll      : std_logic;
    signal ram_acc_a : std_logic;
    signal ack_reg_a : std_logic;
    signal ack_reg_b : std_logic;
    signal rd_a      : std_logic;

    signal bank_a : natural range 0 to BANKS-1;
    signal bank_b : natural range 0 to BANKS-1;
    signal sel_a  : natural range 0 to BANKS-1;
    signal sel_b  : natural range 0 to BANKS-1;

    signal addr_a : std_logic_vector(MACRO_ADDR_BITS-1 downto 0);
    signal addr_b : std_logic_vector(MACRO_ADDR_BITS-1 downto 0);

    signal en_a : std_logic_vector(BANKS-1 downto 0);
    signal en_b : std_logic_vector(BANKS-1 downto 0);

    signal wmask_lo : half_t;
    signal wmask_hi : half_t;

    signal q_lo_a : half_array_t;
    signal q_hi_a : half_array_t;
    signal q_lo_b : half_array_t;
    signal q_hi_b : half_array_t;

begin

    ram_req_a <= cyc_a_i and stb_a_i;
    ram_req_b <= cyc_b_i and stb_b_i;
    rd_a      <= ram_req_a and not we_a_i;

    coll      <= ram_req_a and we_a_i and ram_req_b when adr_a_i = adr_b_i else '0';
    ram_acc_a <= ram_req_a and not coll;

    addr_a <= adr_a_i(MACRO_ADDR_BITS-1 downto 0);
    addr_b <= adr_b_i(MACRO_ADDR_BITS-1 downto 0);

    bank_gt1: if BANK_BITS > 0 generate
        bank_a <= to_integer(unsigned(adr_a_i(BITS-3 downto MACRO_ADDR_BITS)));
        bank_b <= to_integer(unsigned(adr_b_i(BITS-3 downto MACRO_ADDR_BITS)));
    end generate bank_gt1;

    bank_eq1: if BANK_BITS = 0 generate
        bank_a <= 0;
        bank_b <= 0;
    end generate bank_eq1;

    wmask_lo(15 downto 8) <= (others => sel_a_i(1));
    wmask_lo( 7 downto 0) <= (others => sel_a_i(0));
    wmask_hi(15 downto 8) <= (others => sel_a_i(3));
    wmask_hi( 7 downto 0) <= (others => sel_a_i(2));

    macros: for b in 0 to BANKS-1 generate

        en_a(b) <= ram_acc_a when bank_a = b else '0';
        en_b(b) <= ram_req_b when bank_b = b else '0';

        macro_lo: sram_dp generic map (
            ADDR_BITS => MACRO_ADDR_BITS,
            DATA_BITS => 16
        ) port map (
            clk_a   => clk_i,
            en_a    => en_a(b),
            we_a    => we_a_i,
            wmask_a => wmask_lo,
            addr_a  => addr_a,
            d_a     => dat_a_i(15 downto 0),
            q_a     => q_lo_a(b),
            clk_b   => clk_i,
            en_b    => en_b(b),
            we_b    => '0',
            wmask_b => HALF_ZERO,
            addr_b  => addr_b,
            d_b     => HALF_ZERO,
            q_b     => q_lo_b(b)
        );

        macro_hi: sram_dp generic map (
            ADDR_BITS => MACRO_ADDR_BITS,
            DATA_BITS => 16
        ) port map (
            clk_a   => clk_i,
            en_a    => en_a(b),
            we_a    => we_a_i,
            wmask_a => wmask_hi,
            addr_a  => addr_a,
            d_a     => dat_a_i(31 downto 16),
            q_a     => q_hi_a(b),
            clk_b   => clk_i,
            en_b    => en_b(b),
            we_b    => '0',
            wmask_b => HALF_ZERO,
            addr_b  => addr_b,
            d_b     => HALF_ZERO,
            q_b     => q_hi_b(b)
        );

    end generate macros;

    sel_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rd_a = '1' then
                sel_a <= bank_a;
            end if;
            if ram_req_b = '1' then
                sel_b <= bank_b;
            end if;
        end if;
    end process sel_proc;

    ack_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg_a <= '0';
                ack_reg_b <= '0';
            else
                ack_reg_a <= ram_acc_a;
                ack_reg_b <= ram_req_b;
            end if;
        end if;
    end process ack_proc;

    ack_a_o   <= ack_reg_a;
    stall_a_o <= coll;
    ack_b_o   <= ack_reg_b;
    stall_b_o <= '0';

    dat_a_o <= q_hi_a(sel_a) & q_lo_a(sel_a);
    dat_b_o <= q_hi_b(sel_b) & q_lo_b(sel_b);

end architecture macro;

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

    ack_a_o   <= ack_reg_a;
    stall_a_o <= '0';
    dat_a_o   <= dat_reg_a;
    ack_b_o   <= ack_reg_b;
    stall_b_o <= '0';
    dat_b_o   <= dat_reg_b;

end architecture rtl;
