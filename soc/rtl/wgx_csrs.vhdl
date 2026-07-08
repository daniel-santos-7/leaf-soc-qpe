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
        drag_o  : out std_logic_vector(15 downto 0);
        env_o   : out std_logic_vector(31 downto 0);
        delay_o : out std_logic_vector(23 downto 0);
        valid_o : out std_logic;
        ready_i : in  std_logic
    );
end entity wgx_csrs;

architecture rtl of wgx_csrs is

    constant REG_FTW   : std_logic_vector(5 downto 0) := "000000";
    constant REG_POW   : std_logic_vector(5 downto 0) := "000001";
    constant REG_AMP   : std_logic_vector(5 downto 0) := "000010";
    constant REG_DRAG  : std_logic_vector(5 downto 0) := "000011";
    constant REG_ENV   : std_logic_vector(5 downto 0) := "000100";
    constant REG_DELAY : std_logic_vector(5 downto 0) := "000101";
    constant REG_TRIG  : std_logic_vector(5 downto 0) := "000110";

    signal ftw_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal pow_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal amp_reg   : std_logic_vector(15 downto 0) := (others => '0');
    signal drag_reg  : std_logic_vector(15 downto 0) := (others => '0');
    signal env_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal delay_reg : std_logic_vector(23 downto 0) := (others => '0');
    signal valid_reg  : std_logic := '0';
    signal valid_int  : std_logic;

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
            else
                if ready_i = '1' then
                    valid_reg <= '0';
                end if;
                if we_i = '1' then
                    case addr_i is
                        when REG_FTW   => ftw_reg   <= wdata_i;
                        when REG_POW   => pow_reg   <= wdata_i;
                        when REG_AMP   => amp_reg   <= wdata_i(15 downto 0);
                        when REG_DRAG  => drag_reg  <= wdata_i(15 downto 0);
                        when REG_ENV   => env_reg   <= wdata_i;
                        when REG_DELAY => delay_reg <= wdata_i(23 downto 0);
                        when REG_TRIG  =>
                            -- If ready_i='1' the sig_gen is idle, and valid_int
                            -- (combinatorial) delivers a single-cycle pulse via
                            -- valid_o directly; no need to store it.
                            -- If ready_i='0' the sig_gen is busy, so valid_reg
                            -- holds the request until ready_i goes high.
                            if wdata_i(0) = '1' and ready_i = '0' then
                                valid_reg <= '1';
                            end if;
                        when others    => null;
                    end case;
                end if;
            end if;
        end if;
    end process write_proc;

    read_comb : process(addr_i, ftw_reg, pow_reg, amp_reg, drag_reg, env_reg,
                        delay_reg, ready_i, valid_int)
    begin
        case addr_i is
            when REG_FTW   => rdata_o <= ftw_reg;
            when REG_POW   => rdata_o <= pow_reg;
            when REG_AMP   => rdata_o <= x"0000" & amp_reg;
            when REG_DRAG  => rdata_o <= x"0000" & drag_reg;
            when REG_ENV   => rdata_o <= env_reg;
            when REG_DELAY => rdata_o <= x"00" & delay_reg;
            when REG_TRIG  => rdata_o <= (1 => ready_i and not valid_int, others => '0');
            when others    => rdata_o <= (others => '0');
        end case;
    end process read_comb;
    ftw_o   <= ftw_reg;
    pow_o   <= pow_reg;
    amp_o   <= amp_reg;
    drag_o  <= drag_reg;
    env_o   <= env_reg;
    delay_o <= delay_reg;
    -- Combinatorial: pulses high on a trigger write (consumed same-cycle by
    -- sig_gen when ready_i='1'), or reflects the latched valid_reg when busy.
    -- Not registered: the combinatorial path is intentional to allow a
    -- single-cycle handshake without requiring the CPU to poll for idle.
    valid_int <= '1' when ((we_i = '1' and addr_i = REG_TRIG and wdata_i(0) = '1')
                           or valid_reg = '1') else '0';
    valid_o <= valid_int;

end architecture rtl;
