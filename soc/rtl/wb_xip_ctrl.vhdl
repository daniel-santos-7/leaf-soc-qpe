----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: XIP controller (Wishbone to SPI flash)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_pkg.all;

entity wb_xip_ctrl is
    generic (
        CS_HIGH_CYCLES : positive := 2
    );
    port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        cyc_i      : in  std_logic;
        stb_i      : in  std_logic;
        adr_i      : in  std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
        ack_o      : out std_logic;
        err_o      : out std_logic;
        dat_o      : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        dis_i      : in  std_logic;
        tx_valid_o : out std_logic;
        tx_ready_i : in  std_logic;
        tx_data_o  : out std_logic_vector(SPI_WIDTH-1 downto 0);
        tx_bits_o  : out std_logic_vector(SPI_CNT_BITS-1 downto 0);
        rx_data_i  : in  std_logic_vector(SPI_WIDTH-1 downto 0);
        rx_last_i  : in  std_logic;
        rx_valid_i : in  std_logic
    );
end entity wb_xip_ctrl;

architecture rtl of wb_xip_ctrl is

    constant CMD_READ : std_logic_vector(7 downto 0) := x"03";

    type state_t is (IDLE, PEND, ADDR, DATA);

    signal state   : state_t;
    signal req     : std_logic;
    signal fetch   : std_logic;
    signal adr     : std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
    signal adr_reg : std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
    signal err_reg  : std_logic;
    signal hold_cnt : natural range 0 to CS_HIGH_CYCLES-2;
    signal hold_ok  : std_logic;

begin

    assert CS_HIGH_CYCLES >= 2 report "XIP: CS_HIGH_CYCLES must be at least 2." severity failure;

    req   <= cyc_i and stb_i;
    fetch <= '1' when state = IDLE and req = '1' and dis_i = '0' else '0';
    adr   <= adr_i when state = IDLE else adr_reg;

    hold_ok <= '1' when hold_cnt = CS_HIGH_CYCLES-2 else '0';

    fsm_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state   <= IDLE;
                adr_reg <= (others => '0');
            elsif fetch = '1' and tx_ready_i = '1' and hold_ok = '1' then
                state <= ADDR;
            elsif fetch = '1' then
                state   <= PEND;
                adr_reg <= adr_i;
            elsif state = PEND and tx_ready_i = '1' and hold_ok = '1' then
                state <= ADDR;
            elsif state = ADDR and tx_ready_i = '1' then
                state <= DATA;
            elsif state = DATA and rx_valid_i = '1' and rx_last_i = '1' then
                state <= IDLE;
            end if;
        end if;
    end process fsm_proc;

    hold_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                hold_cnt <= CS_HIGH_CYCLES-2;
            elsif rx_valid_i = '1' and rx_last_i = '1' then
                hold_cnt <= 0;
            elsif hold_cnt /= CS_HIGH_CYCLES-2 then
                hold_cnt <= hold_cnt + 1;
            end if;
        end if;
    end process hold_proc;

    err_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                err_reg <= '0';
            elsif state = IDLE and req = '1' and dis_i = '1' then
                err_reg <= '1';
            else
                err_reg <= '0';
            end if;
        end if;
    end process err_proc;

    tx_valid_o <= '1' when ((fetch = '1' or state = PEND) and hold_ok = '1') or state = ADDR else '0';
    tx_data_o  <= (others => '0') when state = ADDR else CMD_READ & adr & "00";
    tx_bits_o  <= std_logic_vector(to_unsigned(SPI_WIDTH, SPI_CNT_BITS));
    ack_o      <= '1' when state = DATA and rx_valid_i = '1' and rx_last_i = '1' else '0';
    err_o      <= err_reg;
    dat_o      <= rx_data_i(7 downto 0) & rx_data_i(15 downto 8) & rx_data_i(23 downto 16) & rx_data_i(31 downto 24);

end architecture rtl;
