----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: dual-port Wishbone RAM built from SRAM macros
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_pkg.all;

entity wb_ram_dp_macro is
    generic (
        BITS            : natural := 14;
        MACRO_ADDR_BITS : natural := 11
    );
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;

        dat_a_i : in  std_logic_vector(31 downto 0);
        cyc_a_i : in  std_logic;
        stb_a_i : in  std_logic;
        we_a_i  : in  std_logic;
        sel_a_i : in  std_logic_vector(3 downto 0);
        adr_a_i : in  std_logic_vector(BITS-3 downto 0);
        ack_a_o : out std_logic;
        dat_a_o : out std_logic_vector(31 downto 0);

        cyc_b_i : in  std_logic;
        stb_b_i : in  std_logic;
        adr_b_i : in  std_logic_vector(BITS-3 downto 0);
        ack_b_o : out std_logic;
        dat_b_o : out std_logic_vector(31 downto 0)
    );
end entity wb_ram_dp_macro;

architecture rtl of wb_ram_dp_macro is

    constant BANK_BITS : natural := BITS - 2 - MACRO_ADDR_BITS;
    constant BANKS     : natural := 2**BANK_BITS;

    subtype half_t is std_logic_vector(15 downto 0);
    type half_array_t is array (0 to BANKS-1) of half_t;

    constant HALF_ZERO : half_t := (others => '0');

    signal ram_req_a : std_logic;
    signal ram_req_b : std_logic;
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

        en_a(b) <= ram_req_a when bank_a = b else '0';
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
                ack_reg_a <= ram_req_a;
                ack_reg_b <= ram_req_b;
            end if;
        end if;
    end process ack_proc;

    ack_a_o <= ack_reg_a;
    ack_b_o <= ack_reg_b;

    dat_a_o <= q_hi_a(sel_a) & q_lo_a(sel_a);
    dat_b_o <= q_hi_b(sel_b) & q_lo_b(sel_b);

end architecture rtl;
