library IEEE;
use IEEE.std_logic_1164.all;
use work.sig_gen_pkg.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity wgx_csrs is
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;
        addr_i  : in  std_logic_vector(5 downto 0);
        wdata_i : in  std_logic_vector(31 downto 0);
        we_i    : in  std_logic;
        rdata_o : out std_logic_vector(31 downto 0);
        inc_o   : out std_logic_vector(31 downto 0);
        pha_o   : out std_logic_vector(31 downto 0);
        amp_o   : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        we_o    : out std_logic
    );
end entity wgx_csrs;

architecture rtl of wgx_csrs is

    constant ADDR_INC  : std_logic_vector(5 downto 0) := "000000";
    constant ADDR_PHA  : std_logic_vector(5 downto 0) := "000001";
    constant ADDR_AMP  : std_logic_vector(5 downto 0) := "000010";
    constant ADDR_CTRL : std_logic_vector(5 downto 0) := "000011";

    signal inc_reg  : std_logic_vector(31 downto 0);
    signal pha_reg  : std_logic_vector(31 downto 0);
    signal amp_reg  : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal ctrl_reg : std_logic;

begin

    process(clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                inc_reg  <= (others => '0');
                pha_reg  <= (others => '0');
                amp_reg  <= (others => '0');
                ctrl_reg <= '0';
            else
                if we_i = '1' then
                    case addr_i is
                        when ADDR_INC =>
                            inc_reg <= wdata_i;
                        when ADDR_PHA =>
                            pha_reg <= wdata_i;
                        when ADDR_AMP =>
                            amp_reg <= wdata_i(OUT_RES_BITS-1 downto 0);
                        when ADDR_CTRL =>
                            ctrl_reg <= wdata_i(0);
                        when others =>
                            null;
                    end case;
                else
                    ctrl_reg <= '0';
                end if;
            end if;
        end if;
    end process;

    process(addr_i, inc_reg, pha_reg, amp_reg) is
    begin
        case addr_i is
            when ADDR_INC =>
                rdata_o <= inc_reg;
            when ADDR_PHA =>
                rdata_o <= pha_reg;
            when ADDR_AMP =>
                rdata_o <= (31 downto OUT_RES_BITS => '0') & amp_reg;
            when others =>
                rdata_o <= (others => '0');
        end case;
    end process;

    inc_o <= inc_reg;
    pha_o <= pha_reg;
    amp_o <= amp_reg;
    we_o  <= ctrl_reg;

end architecture rtl;
