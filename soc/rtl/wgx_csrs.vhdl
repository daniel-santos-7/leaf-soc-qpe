library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity wgx_csrs is
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;
        addr_i  : in  std_logic_vector(5 downto 0);
        wdata_i : in  std_logic_vector(31 downto 0);
        we_i    : in  std_logic;
        rdata_o : out std_logic_vector(31 downto 0);
        ftw_o   : out std_logic_vector(31 downto 0);
        pow_o   : out std_logic_vector(31 downto 0);
        amp_o   : out std_logic_vector(15 downto 0);
        env_o   : out std_logic_vector(31 downto 0);
        drag_o  : out std_logic_vector(15 downto 0);
        valid_o : out std_logic;
        delay_o : out std_logic_vector(23 downto 0);
        ready_i : in  std_logic
    );
end entity wgx_csrs;

architecture rtl of wgx_csrs is

    constant ADDR_FTW   : std_logic_vector(5 downto 0) := "000000";
    constant ADDR_POW   : std_logic_vector(5 downto 0) := "000001";
    constant ADDR_AMP   : std_logic_vector(5 downto 0) := "000010";
    constant ADDR_ENV   : std_logic_vector(5 downto 0) := "000011";
    constant ADDR_DRAG  : std_logic_vector(5 downto 0) := "000100";
    constant ADDR_DELAY : std_logic_vector(5 downto 0) := "000101";
    constant ADDR_TRIG  : std_logic_vector(5 downto 0) := "000110";

    signal ftw_reg  : std_logic_vector(31 downto 0);
    signal pow_reg  : std_logic_vector(31 downto 0);
    signal amp_reg  : std_logic_vector(15 downto 0);
    signal env_reg  : std_logic_vector(31 downto 0);
    signal drag_reg : std_logic_vector(15 downto 0);
    signal delay_reg : std_logic_vector(23 downto 0);
    signal valid_reg : std_logic;

begin

    process(clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ftw_reg   <= (others => '0');
                pow_reg   <= (others => '0');
                amp_reg   <= (others => '0');
                env_reg   <= (others => '0');
                drag_reg  <= (others => '0');
                delay_reg <= (others => '0');
                valid_reg <= '0';
            else
                if valid_reg = '1' and ready_i = '1' then
                    valid_reg <= '0';
                end if;
                if we_i = '1' then
                    case addr_i is
                        when ADDR_FTW =>
                            ftw_reg <= wdata_i;
                        when ADDR_POW =>
                            pow_reg <= wdata_i;
                        when ADDR_AMP =>
                            amp_reg <= wdata_i(15 downto 0);
                        when ADDR_ENV =>
                            env_reg <= wdata_i;
                        when ADDR_DRAG =>
                            drag_reg <= wdata_i(15 downto 0);
                        when ADDR_DELAY =>
                            delay_reg <= wdata_i(23 downto 0);
                        when ADDR_TRIG =>
                            valid_reg <= '1';
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process;

    with addr_i select rdata_o <=
        ftw_reg                         when ADDR_FTW,
        pow_reg                         when ADDR_POW,
        x"0000" & amp_reg               when ADDR_AMP,
        env_reg                         when ADDR_ENV,
        x"0000" & drag_reg              when ADDR_DRAG,
        x"00" & delay_reg               when ADDR_DELAY,
        x"000000" & "000000" & ready_i & valid_reg when ADDR_TRIG,
        (others => '0')                 when others;

    ftw_o   <= ftw_reg;
    pow_o   <= pow_reg;
    amp_o   <= amp_reg;
    env_o   <= env_reg;
    drag_o  <= drag_reg;
    valid_o <= valid_reg;
    delay_o <= delay_reg;

end architecture rtl;
