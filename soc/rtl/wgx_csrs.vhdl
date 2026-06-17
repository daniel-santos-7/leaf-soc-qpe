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
        ready_i : in  std_logic;
        irq_o   : out std_logic
    );
end entity wgx_csrs;

architecture rtl of wgx_csrs is

    constant ADDR_FTW   : std_logic_vector(5 downto 0) := "000000";
    constant ADDR_POW   : std_logic_vector(5 downto 0) := "000001";
    constant ADDR_AMP   : std_logic_vector(5 downto 0) := "000010";
    constant ADDR_ENV   : std_logic_vector(5 downto 0) := "000011";
    constant ADDR_DRAG  : std_logic_vector(5 downto 0) := "000100";
    constant ADDR_DELAY : std_logic_vector(5 downto 0) := "000101";
    constant ADDR_STAT  : std_logic_vector(5 downto 0) := "000110";
    constant ADDR_SEQ_LEN    : std_logic_vector(5 downto 0) := "000111";
    constant ADDR_SEQ_PTR    : std_logic_vector(5 downto 0) := "001000";
    constant ADDR_SEQ_DATA   : std_logic_vector(5 downto 0) := "001001";
    constant ADDR_SEQ_CTRL   : std_logic_vector(5 downto 0) := "001010";
    constant ADDR_SEQ_REPEAT : std_logic_vector(5 downto 0) := "001011";

    type seq_entry_t is record
        ftw   : std_logic_vector(31 downto 0);
        pow   : std_logic_vector(31 downto 0);
        amp   : std_logic_vector(15 downto 0);
        env   : std_logic_vector(31 downto 0);
        drag  : std_logic_vector(15 downto 0);
        delay : std_logic_vector(23 downto 0);
    end record seq_entry_t;

    type seq_ram_t is array(0 to 7) of seq_entry_t;
    signal seq_ram : seq_ram_t;

    -- CPU-owned
    signal seq_len   : unsigned(2 downto 0) := "001";
    signal entry_ptr : unsigned(2 downto 0) := (others => '0');
    signal sub_ptr   : unsigned(2 downto 0) := (others => '0');
    signal seq_repeat : std_logic_vector(31 downto 0) := (others => '0');

    -- FSM-owned
    type state_t is (IDLE, LOAD, TRIGGER, NEXT_ENTRY, FINISH);
    signal state    : state_t := IDLE;
    signal fsm_ptr  : unsigned(2 downto 0) := (others => '0');
    signal play_cnt : unsigned(31 downto 0) := (others => '0');
    signal done     : std_logic := '0';

    signal seq_ftw   : std_logic_vector(31 downto 0) := (others => '0');
    signal seq_pow   : std_logic_vector(31 downto 0) := (others => '0');
    signal seq_amp   : std_logic_vector(15 downto 0) := (others => '0');
    signal seq_env   : std_logic_vector(31 downto 0) := (others => '0');
    signal seq_drag  : std_logic_vector(15 downto 0) := (others => '0');
    signal seq_delay : std_logic_vector(23 downto 0) := (others => '0');
    signal seq_valid : std_logic := '0';

    signal start_req  : std_logic;
    signal clear_req  : std_logic;
    signal busy_int   : std_logic;

begin

    start_req <= '1' when we_i = '1' and addr_i = ADDR_SEQ_CTRL
                      and wdata_i(0) = '1' and state = IDLE else '0';
    clear_req <= '1' when we_i = '1' and addr_i = ADDR_SEQ_CTRL
                      and wdata_i(0) = '0' and state = IDLE else '0';
    busy_int  <= '0' when state = IDLE else '1';
    irq_o     <= done;

    p_cpu: process(clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                seq_ram    <= (others => (
                    ftw   => (others => '0'),
                    pow   => (others => '0'),
                    amp   => (others => '0'),
                    env   => (others => '0'),
                    drag  => (others => '0'),
                    delay => (others => '0')
                ));
                seq_len    <= "001";
                entry_ptr  <= (others => '0');
                sub_ptr    <= (others => '0');
                seq_repeat <= (others => '0');
            else
                if we_i = '1' then
                    case addr_i is
                        when ADDR_FTW =>
                            seq_ram(0).ftw <= wdata_i;
                        when ADDR_POW =>
                            seq_ram(0).pow <= wdata_i;
                        when ADDR_AMP =>
                            seq_ram(0).amp <= wdata_i(15 downto 0);
                        when ADDR_ENV =>
                            seq_ram(0).env <= wdata_i;
                        when ADDR_DRAG =>
                            seq_ram(0).drag <= wdata_i(15 downto 0);
                        when ADDR_DELAY =>
                            seq_ram(0).delay <= wdata_i(23 downto 0);
                        when ADDR_SEQ_LEN =>
                            if wdata_i(2 downto 0) = "000" then
                                seq_len <= "001";
                            else
                                seq_len <= unsigned(wdata_i(2 downto 0));
                            end if;
                        when ADDR_SEQ_PTR =>
                            entry_ptr <= unsigned(wdata_i(2 downto 0));
                            sub_ptr   <= (others => '0');
                        when ADDR_SEQ_DATA =>
                            if to_integer(sub_ptr) = 0 then
                                seq_ram(to_integer(entry_ptr)).ftw   <= wdata_i;
                            elsif to_integer(sub_ptr) = 1 then
                                seq_ram(to_integer(entry_ptr)).pow   <= wdata_i;
                            elsif to_integer(sub_ptr) = 2 then
                                seq_ram(to_integer(entry_ptr)).amp   <= wdata_i(15 downto 0);
                            elsif to_integer(sub_ptr) = 3 then
                                seq_ram(to_integer(entry_ptr)).env   <= wdata_i;
                            elsif to_integer(sub_ptr) = 4 then
                                seq_ram(to_integer(entry_ptr)).drag  <= wdata_i(15 downto 0);
                            elsif to_integer(sub_ptr) = 5 then
                                seq_ram(to_integer(entry_ptr)).delay <= wdata_i(23 downto 0);
                            end if;
                            if sub_ptr < 5 then
                                sub_ptr <= sub_ptr + 1;
                            else
                                sub_ptr <= (others => '0');
                            end if;
                        when ADDR_SEQ_REPEAT =>
                            seq_repeat <= wdata_i;
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process p_cpu;

    p_fsm: process(clk_i) is
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state    <= IDLE;
                fsm_ptr  <= (others => '0');
                play_cnt <= (others => '0');
                done     <= '0';
                seq_ftw   <= (others => '0');
                seq_pow   <= (others => '0');
                seq_amp   <= (others => '0');
                seq_env   <= (others => '0');
                seq_drag  <= (others => '0');
                seq_delay <= (others => '0');
                seq_valid <= '0';
            else
                case state is
                    when IDLE =>
                        if start_req = '1' then
                            state    <= LOAD;
                            fsm_ptr  <= (others => '0');
                            play_cnt <= unsigned(seq_repeat);
                            done     <= '0';
                        elsif clear_req = '1' then
                            done     <= '0';
                        end if;

                    when LOAD =>
                        seq_ftw   <= seq_ram(to_integer(fsm_ptr)).ftw;
                        seq_pow   <= seq_ram(to_integer(fsm_ptr)).pow;
                        seq_amp   <= seq_ram(to_integer(fsm_ptr)).amp;
                        seq_env   <= seq_ram(to_integer(fsm_ptr)).env;
                        seq_drag  <= seq_ram(to_integer(fsm_ptr)).drag;
                        seq_delay <= seq_ram(to_integer(fsm_ptr)).delay;
                        seq_valid <= '1';
                        state <= TRIGGER;

                    when TRIGGER =>
                        if ready_i = '1' then
                            seq_valid <= '0';
                            state <= NEXT_ENTRY;
                        end if;

                    when NEXT_ENTRY =>
                        if fsm_ptr < seq_len - 1 then
                            fsm_ptr <= fsm_ptr + 1;
                            state <= LOAD;
                        else
                            if play_cnt = 0 then
                                fsm_ptr <= (others => '0');
                                state <= LOAD;
                            elsif play_cnt > 1 then
                                play_cnt <= play_cnt - 1;
                                fsm_ptr <= (others => '0');
                                state <= LOAD;
                            else
                                state <= FINISH;
                            end if;
                        end if;

                    when FINISH =>
                        seq_valid <= '0';
                        done <= '1';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process p_fsm;

    with addr_i select rdata_o <=
        seq_ftw                            when ADDR_FTW,
        seq_pow                            when ADDR_POW,
        x"0000" & seq_amp                  when ADDR_AMP,
        seq_env                            when ADDR_ENV,
        x"0000" & seq_drag                 when ADDR_DRAG,
        x"00" & seq_delay                  when ADDR_DELAY,
        x"000000" & "000000" & ready_i & seq_valid when ADDR_STAT,
        x"000000" & "00000" & std_logic_vector(seq_len) when ADDR_SEQ_LEN,
        x"000000" & "00000" & std_logic_vector(entry_ptr) when ADDR_SEQ_PTR,
        (others => '0')                    when ADDR_SEQ_DATA,
        x"000000" & "000000" & done & busy_int when ADDR_SEQ_CTRL,
        seq_repeat                         when ADDR_SEQ_REPEAT,
        (others => '0')                    when others;

    ftw_o   <= seq_ftw;
    pow_o   <= seq_pow;
    amp_o   <= seq_amp;
    env_o   <= seq_env;
    drag_o  <= seq_drag;
    delay_o <= seq_delay;
    valid_o <= seq_valid;

end architecture rtl;
