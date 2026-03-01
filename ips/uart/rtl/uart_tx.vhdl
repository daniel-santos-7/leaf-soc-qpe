library IEEE;
library work;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.uart_pkg.all;

entity uart_tx is
    port (
        clk_i: in  std_logic;
        rst_i: in  std_logic;
        div_i: in  std_logic_vector(15 downto 0);
        vld_i: in  std_logic;
        dat_i: in  std_logic_vector(7 downto 0);
        rdy_o: out std_logic;
        tx_o:  out std_logic
    );
end entity uart_tx;

architecture rtl of uart_tx is

    constant TX_COUNTER_MAX : unsigned(2 downto 0) := (others => '1');

    type state_t is (IDLE, TX_START, TX_DATA, TX_STOP);

    signal state_reg: state_t;

    signal rdy_reg : std_logic;
    signal tx_reg  : std_logic;

    signal baud_cnt_en : std_logic;
    signal tx_cnt_en : std_logic;
    signal data_reg_en : std_logic;

    signal baud_cnt : unsigned(15 downto 0);
    signal tx_cnt : unsigned(2 downto 0);
    signal next_tx_cnt : unsigned(2 downto 0);

    signal data_reg : std_logic_vector(7 downto 0);

    signal baud_cnt_done : std_logic;
    signal tx_cnt_done : std_logic;

begin

    ----------------------- Control Logic (FSM) --------------------------

    state_reg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state_reg <= IDLE;
                rdy_reg <= '1';
                tx_reg <= '1';
            else
                case state_reg is
                    when IDLE =>
                        if vld_i = '1' then
                            state_reg <= TX_START;
                            rdy_reg <= '0';
                            tx_reg <= '0';
                        end if;
                    when TX_START =>
                        if baud_cnt_done = '1' then
                            state_reg <= TX_DATA;
                            tx_reg <= data_reg(to_integer(tx_cnt));
                        end if;
                    when TX_DATA =>
                        if baud_cnt_done = '1' then
                            if tx_cnt_done = '1' then
                                state_reg <= TX_STOP;
                                tx_reg <= '1';
                            else
                                tx_reg <= data_reg(to_integer(next_tx_cnt));
                            end if;
                        end if;
                    when TX_STOP =>
                        if baud_cnt_done = '1' then
                            state_reg <= IDLE;
                            rdy_reg <= '1';
                            tx_reg <= '1';
                        end if;
                end case;
            end if;
        end if;
    end process state_reg_proc;

    baud_cnt_en <= '0' when state_reg = IDLE else '1';
    tx_cnt_en <= baud_cnt_done when state_reg = TX_DATA else '0';
    data_reg_en <= vld_i when state_reg = IDLE else '0';

    ----------------------- Datapath Logic -----------------------------

    baud_cnt_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                baud_cnt <= (others => '0');
            elsif baud_cnt_en = '1' then
                if baud_cnt_done = '1' then
                    baud_cnt <= (others => '0');
                else
                    baud_cnt <= (baud_cnt + 1);
                end if;
            end if;
        end if;
    end process baud_cnt_proc;

    tx_cnt_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                tx_cnt <= (others => '0');
            elsif tx_cnt_en = '1' then
                if tx_cnt_done = '1' then
                    tx_cnt <= (others => '0');
                else
                    tx_cnt <= next_tx_cnt;
                end if;
            end if;
        end if;
    end process tx_cnt_proc;

    next_tx_cnt <= tx_cnt + 1;

    data_reg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                data_reg <= (others => '0');
            elsif data_reg_en = '1' then
                data_reg <= dat_i;
            end if;
        end if;
    end process data_reg_proc;

    baud_cnt_done <= '1' when baud_cnt = (unsigned(div_i) - 1) else '0';
    tx_cnt_done <= '1' when tx_cnt = TX_COUNTER_MAX else '0';

    ------------------------------ Outputs  ------------------------------

    rdy_o <= rdy_reg;
    tx_o <= tx_reg;

end architecture rtl;
