library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity qpe_csrs is
    port (
        clk_i   : in  std_logic;
        rst_i   : in  std_logic;
        addr_i  : in  std_logic_vector(5 downto 0);
        wdata_i : in  std_logic_vector(31 downto 0);
        we_i    : in  std_logic;
        rdata_o : out std_logic_vector(31 downto 0);

        -- Register-file write snoop: broadcasts the same (we, addr, data)
        -- the CPU's own register file write port sees. Used to mirror the
        -- GPR each parameter is pointed at, without needing dedicated
        -- read ports on the register file (which cost a full read-mux per
        -- port and synthesized very poorly).
        rf_we_i       : in  std_logic;
        rf_wr_addr_i  : in  std_logic_vector(4 downto 0);
        rf_wr_data_i  : in  std_logic_vector(31 downto 0);

        ftw_o   : out std_logic_vector(31 downto 0);
        pow_o   : out std_logic_vector(31 downto 0);
        amp_o   : out std_logic_vector(15 downto 0);
        drag_o  : out std_logic_vector(15 downto 0);
        env_o   : out std_logic_vector(31 downto 0);
        delay_o : out std_logic_vector(23 downto 0);
        valid_o : out std_logic;
        ready_i : in  std_logic
    );
end entity qpe_csrs;

architecture rtl of qpe_csrs is

    constant REG_FTW   : std_logic_vector(5 downto 0) := "000000";
    constant REG_POW   : std_logic_vector(5 downto 0) := "000001";
    constant REG_AMP   : std_logic_vector(5 downto 0) := "000010";
    constant REG_DRAG  : std_logic_vector(5 downto 0) := "000011";
    constant REG_ENV   : std_logic_vector(5 downto 0) := "000100";
    constant REG_DELAY : std_logic_vector(5 downto 0) := "000101";
    constant REG_TRIG  : std_logic_vector(5 downto 0) := "000110";

    -- Pointers: which GPR (0-31) holds each parameter's value.
    signal ftw_ptr   : std_logic_vector(4 downto 0) := (others => '0');
    signal pow_ptr   : std_logic_vector(4 downto 0) := (others => '0');
    signal amp_ptr   : std_logic_vector(4 downto 0) := (others => '0');
    signal drag_ptr  : std_logic_vector(4 downto 0) := (others => '0');
    signal env_ptr   : std_logic_vector(4 downto 0) := (others => '0');
    signal delay_ptr : std_logic_vector(4 downto 0) := (others => '0');

    -- Mirrors: last value seen written to the pointed-at GPR.
    signal ftw_val   : std_logic_vector(31 downto 0) := (others => '0');
    signal pow_val   : std_logic_vector(31 downto 0) := (others => '0');
    signal amp_val   : std_logic_vector(31 downto 0) := (others => '0');
    signal drag_val  : std_logic_vector(31 downto 0) := (others => '0');
    signal env_val   : std_logic_vector(31 downto 0) := (others => '0');
    signal delay_val : std_logic_vector(31 downto 0) := (others => '0');

    signal valid_reg  : std_logic := '0';
    signal valid_int  : std_logic;

begin

    write_proc : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ftw_ptr   <= (others => '0');
                pow_ptr   <= (others => '0');
                amp_ptr   <= (others => '0');
                drag_ptr  <= (others => '0');
                env_ptr   <= (others => '0');
                delay_ptr <= (others => '0');
                ftw_val   <= (others => '0');
                pow_val   <= (others => '0');
                amp_val   <= (others => '0');
                drag_val  <= (others => '0');
                env_val   <= (others => '0');
                delay_val <= (others => '0');
                valid_reg <= '0';
            else
                if ready_i = '1' then
                    valid_reg <= '0';
                end if;
                if we_i = '1' then
                    case addr_i is
                        when REG_FTW   => ftw_ptr   <= wdata_i(4 downto 0);
                        when REG_POW   => pow_ptr   <= wdata_i(4 downto 0);
                        when REG_AMP   => amp_ptr   <= wdata_i(4 downto 0);
                        when REG_DRAG  => drag_ptr  <= wdata_i(4 downto 0);
                        when REG_ENV   => env_ptr   <= wdata_i(4 downto 0);
                        when REG_DELAY => delay_ptr <= wdata_i(4 downto 0);
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

                -- Mirror update: a GPR write whose address matches a stored
                -- pointer updates that parameter's mirror with the value
                -- being written. x0 is excluded to match reg_file's own
                -- write suppression for x0 (always reads back as 0).
                if rf_we_i = '1' and rf_wr_addr_i /= "00000" then
                    if rf_wr_addr_i = ftw_ptr   then ftw_val   <= rf_wr_data_i; end if;
                    if rf_wr_addr_i = pow_ptr   then pow_val   <= rf_wr_data_i; end if;
                    if rf_wr_addr_i = amp_ptr   then amp_val   <= rf_wr_data_i; end if;
                    if rf_wr_addr_i = drag_ptr  then drag_val  <= rf_wr_data_i; end if;
                    if rf_wr_addr_i = env_ptr   then env_val   <= rf_wr_data_i; end if;
                    if rf_wr_addr_i = delay_ptr then delay_val <= rf_wr_data_i; end if;
                end if;
            end if;
        end if;
    end process write_proc;

    read_comb : process(addr_i, ftw_ptr, pow_ptr, amp_ptr, drag_ptr, env_ptr,
                        delay_ptr, ready_i, valid_int)
    begin
        case addr_i is
            when REG_FTW   => rdata_o <= std_logic_vector(resize(unsigned(ftw_ptr), 32));
            when REG_POW   => rdata_o <= std_logic_vector(resize(unsigned(pow_ptr), 32));
            when REG_AMP   => rdata_o <= std_logic_vector(resize(unsigned(amp_ptr), 32));
            when REG_DRAG  => rdata_o <= std_logic_vector(resize(unsigned(drag_ptr), 32));
            when REG_ENV   => rdata_o <= std_logic_vector(resize(unsigned(env_ptr), 32));
            when REG_DELAY => rdata_o <= std_logic_vector(resize(unsigned(delay_ptr), 32));
            when REG_TRIG  => rdata_o <= (1 => ready_i and not valid_int, others => '0');
            when others    => rdata_o <= (others => '0');
        end case;
    end process read_comb;

    ftw_o   <= ftw_val;
    pow_o   <= pow_val;
    amp_o   <= amp_val(15 downto 0);
    drag_o  <= drag_val(15 downto 0);
    env_o   <= env_val;
    delay_o <= delay_val(23 downto 0);
    -- Combinatorial: pulses high on a trigger write (consumed same-cycle by
    -- sig_gen when ready_i='1'), or reflects the latched valid_reg when busy.
    -- Not registered: the combinatorial path is intentional to allow a
    -- single-cycle handshake without requiring the CPU to poll for idle.
    valid_int <= '1' when ((we_i = '1' and addr_i = REG_TRIG and wdata_i(0) = '1')
                           or valid_reg = '1') else '0';
    valid_o <= valid_int;

end architecture rtl;
