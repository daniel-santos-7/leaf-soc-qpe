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

    constant NUM_BANKS : integer := 12;
    constant ADDR_CTRL : integer := 63;

    subtype bank_range is integer range 0 to NUM_BANKS - 1;

    type ftw_arr_t   is array (bank_range) of std_logic_vector(31 downto 0);
    type pow_arr_t   is array (bank_range) of std_logic_vector(31 downto 0);
    type amp_arr_t   is array (bank_range) of std_logic_vector(15 downto 0);
    type drag_arr_t  is array (bank_range) of std_logic_vector(15 downto 0);
    type env_arr_t   is array (bank_range) of std_logic_vector(31 downto 0);
    type delay_arr_t is array (bank_range) of std_logic_vector(23 downto 0);

    signal bank_ftw   : ftw_arr_t   := (others => (others => '0'));
    signal bank_pow   : pow_arr_t   := (others => (others => '0'));
    signal bank_amp   : amp_arr_t   := (others => (others => '0'));
    signal bank_drag  : drag_arr_t  := (others => (others => '0'));
    signal bank_env   : env_arr_t   := (others => (others => '0'));
    signal bank_delay : delay_arr_t := (others => (others => '0'));

    signal rdata_reg : std_logic_vector(31 downto 0) := (others => '0');

    -- Sequencer FSM
    type seq_state_t is (IDLE, LAUNCH, WAIT_READY);
    signal seq_state : seq_state_t := IDLE;
    signal seq_cnt   : unsigned(3 downto 0) := (others => '0');
    signal seq_count : unsigned(3 downto 0) := (others => '0');

    signal ctrl_start_reg : std_logic := '0';
    signal ctrl_count_reg : unsigned(3 downto 0) := (others => '0');
    signal active : std_logic := '0';

    -- Registered outs from the sequencer
    signal valid_reg : std_logic := '0';
    signal ftw_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal pow_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal amp_reg   : std_logic_vector(15 downto 0) := (others => '0');
    signal drag_reg  : std_logic_vector(15 downto 0) := (others => '0');
    signal env_reg   : std_logic_vector(31 downto 0) := (others => '0');
    signal delay_reg : std_logic_vector(23 downto 0) := (others => '0');

begin

    write_proc : process(clk_i)
        variable addr_val : integer range 0 to 63;
        variable bn : integer range 0 to NUM_BANKS - 1;
        variable rn : integer range 0 to 4;
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                bank_ftw      <= (others => (others => '0'));
                bank_pow      <= (others => (others => '0'));
                bank_amp      <= (others => (others => '0'));
                bank_drag     <= (others => (others => '0'));
                bank_env      <= (others => (others => '0'));
                bank_delay    <= (others => (others => '0'));
                ctrl_start_reg <= '0';
                ctrl_count_reg <= (others => '0');
            else
                ctrl_start_reg <= '0';
                if we_i = '1' then
                    addr_val := to_integer(unsigned(addr_i));
                    if addr_val < NUM_BANKS * 5 then
                        bn := addr_val / 5;
                        rn := addr_val mod 5;
                        case rn is
                            when 0 => bank_ftw(bn)   <= wdata_i;
                            when 1 => bank_pow(bn)   <= wdata_i;
                            when 2 =>
                                bank_amp(bn)  <= wdata_i(15 downto 0);
                                bank_drag(bn) <= wdata_i(31 downto 16);
                            when 3 => bank_env(bn)   <= wdata_i;
                            when 4 => bank_delay(bn) <= wdata_i(23 downto 0);
                            when others => null;
                        end case;
                    elsif addr_val = ADDR_CTRL then
                        ctrl_count_reg <= unsigned(wdata_i(7 downto 4));
                        if wdata_i(0) = '1' then
                            ctrl_start_reg <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process write_proc;

    read_proc : process(clk_i)
        variable addr_val : integer range 0 to 63;
        variable bn : integer range 0 to NUM_BANKS - 1;
        variable rn : integer range 0 to 4;
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                rdata_reg <= (others => '0');
            else
                addr_val := to_integer(unsigned(addr_i));
                if addr_val < NUM_BANKS * 5 then
                    bn := addr_val / 5;
                    rn := addr_val mod 5;
                    case rn is
                        when 0 => rdata_reg <= bank_ftw(bn);
                        when 1 => rdata_reg <= bank_pow(bn);
                        when 2 => rdata_reg <= bank_drag(bn) & bank_amp(bn);
                        when 3 => rdata_reg <= bank_env(bn);
                        when 4 => rdata_reg <= x"00" & bank_delay(bn);
                        when others => rdata_reg <= (others => '0');
                    end case;
                elsif addr_val = ADDR_CTRL then
                    rdata_reg <= (others => '0');
                    rdata_reg(0) <= active;
                else
                    rdata_reg <= (others => '0');
                end if;
            end if;
        end if;
    end process read_proc;

    rdata_o <= rdata_reg;

    -- Sequencer FSM
    seq_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                seq_state    <= IDLE;
                seq_cnt      <= (others => '0');
                seq_count    <= (others => '0');
                valid_reg    <= '0';
                active       <= '0';
            else
                case seq_state is
                    when IDLE =>
                        valid_reg <= '0';
                        active    <= '0';
                        if ctrl_start_reg = '1' then
                            seq_cnt   <= (others => '0');
                            seq_count <= ctrl_count_reg;
                            seq_state <= LAUNCH;
                        end if;

                    when LAUNCH =>
                        valid_reg <= '1';
                        active    <= '1';
                        seq_state <= WAIT_READY;

                    when WAIT_READY =>
                        if ready_i = '1' then
                            if seq_cnt + 1 >= seq_count then
                                valid_reg <= '0';
                                seq_state <= IDLE;
                            else
                                seq_cnt   <= seq_cnt + 1;
                                seq_state <= LAUNCH;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process seq_proc;

    -- Output mux: select data from the current bank
    mux_proc : process(seq_cnt, bank_ftw, bank_pow, bank_amp, bank_drag, bank_env, bank_delay)
        variable idx : integer range 0 to 11;
    begin
        idx := to_integer(seq_cnt);
        ftw_reg   <= bank_ftw(idx);
        pow_reg   <= bank_pow(idx);
        amp_reg   <= bank_amp(idx);
        drag_reg  <= bank_drag(idx);
        env_reg   <= bank_env(idx);
        delay_reg <= bank_delay(idx);
    end process mux_proc;

    ftw_o   <= ftw_reg;
    pow_o   <= pow_reg;
    amp_o   <= amp_reg;
    drag_o  <= drag_reg;
    env_o   <= env_reg;
    delay_o <= delay_reg;
    valid_o <= valid_reg;

end architecture rtl;
