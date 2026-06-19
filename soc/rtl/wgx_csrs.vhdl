library IEEE;
use IEEE.std_logic_1164.all;

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
        drag_o  : out std_logic_vector(15 downto 0);
        env_o   : out std_logic_vector(31 downto 0);
        delay_o : out std_logic_vector(23 downto 0);
        valid_o      : out std_logic;
        start_o      : out std_logic;
        ready_i      : in  std_logic;
        pend_i : in  std_logic_vector(3 downto 0)
    );
end entity wgx_csrs;

architecture rtl of wgx_csrs is

    constant ADDR_FTW   : std_logic_vector(5 downto 0) := "000000";
    constant ADDR_POW   : std_logic_vector(5 downto 0) := "000001";
    constant ADDR_AMP   : std_logic_vector(5 downto 0) := "000010";
    constant ADDR_ENV   : std_logic_vector(5 downto 0) := "000011";
    constant ADDR_DELAY : std_logic_vector(5 downto 0) := "000100";
    constant ADDR_TRIG  : std_logic_vector(5 downto 0) := "000101";
    constant ADDR_CTRL  : std_logic_vector(5 downto 0) := "000110";

    signal ftw_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal pow_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal amp_reg   : std_logic_vector(15 downto 0) := (others => '0');
    signal drag_reg  : std_logic_vector(15 downto 0) := (others => '0');
    signal env_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal delay_reg : std_logic_vector(23 downto 0) := (others => '0');
    signal valid_reg : std_logic := '0';
    signal start_reg : std_logic := '0';

    signal rdata_reg : std_logic_vector(31 downto 0) := (others => '0');

begin

    write_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ftw_reg   <= (others => '0');
                pow_reg   <= (others => '0');
                amp_reg   <= (others => '0');
                drag_reg  <= (others => '0');
                env_reg   <= (others => '0');
                delay_reg <= (others => '0');
                valid_reg <= '0';
                start_reg <= '0';
            else
                valid_reg <= '0';
                start_reg <= '0';
                if we_i = '1' then
                    case addr_i is
                        when ADDR_FTW =>
                            ftw_reg <= wdata_i;
                        when ADDR_POW =>
                            pow_reg <= wdata_i;
                        when ADDR_AMP =>
                            amp_reg  <= wdata_i(15 downto 0);
                            drag_reg <= wdata_i(31 downto 16);
                        when ADDR_ENV =>
                            env_reg <= wdata_i;
                        when ADDR_DELAY =>
                            delay_reg <= wdata_i(23 downto 0);
                        when ADDR_TRIG =>
                            valid_reg <= wdata_i(0);
                        when ADDR_CTRL =>
                            start_reg <= wdata_i(0);
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process write_proc;

    read_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                rdata_reg <= (others => '0');
            else
                case addr_i is
                    when ADDR_FTW   => rdata_reg <= ftw_reg;
                    when ADDR_POW   => rdata_reg <= pow_reg;
                    when ADDR_AMP   => rdata_reg <= drag_reg & amp_reg;
                    when ADDR_ENV   => rdata_reg <= env_reg;
                    when ADDR_DELAY => rdata_reg <= x"00" & delay_reg;
                    when ADDR_TRIG  => rdata_reg <= (others => '0'); rdata_reg(7 downto 4) <= pend_i; rdata_reg(1) <= ready_i; rdata_reg(0) <= valid_reg;
                    when ADDR_CTRL  => rdata_reg <= (others => '0'); rdata_reg(0) <= start_reg;
                    when others     => rdata_reg <= (others => '0');
                end case;
            end if;
        end if;
    end process read_proc;

    rdata_o <= rdata_reg;

    ftw_o   <= ftw_reg;
    pow_o   <= pow_reg;
    amp_o   <= amp_reg;
    drag_o  <= drag_reg;
    env_o   <= env_reg;
    delay_o <= delay_reg;
    valid_o <= valid_reg;
    start_o <= start_reg;

end architecture rtl;
