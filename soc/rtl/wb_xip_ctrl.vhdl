----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: XIP controller (Wishbone to SPI flash)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_soc_pkg.all;

entity wb_xip_ctrl is
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
        start_o    : out std_logic;
        ready_i    : in  std_logic;
        tx_data_o  : out std_logic_vector(SPI_WIDTH-1 downto 0);
        rx_data_i  : in  std_logic_vector(SPI_WIDTH-1 downto 0);
        rx_valid_i : in  std_logic
    );
end entity wb_xip_ctrl;

architecture rtl of wb_xip_ctrl is

    constant CMD_READ : std_logic_vector(7 downto 0) := x"03";

    type state_t is (IDLE, PEND, BUSY);

    signal state   : state_t;
    signal req     : std_logic;
    signal fetch   : std_logic;
    signal adr     : std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
    signal adr_reg : std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
    signal err_reg : std_logic;

begin

    req   <= cyc_i and stb_i;
    fetch <= '1' when state = IDLE and req = '1' and dis_i = '0' else '0';
    adr   <= adr_i when state = IDLE else adr_reg;

    fsm_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state   <= IDLE;
                adr_reg <= (others => '0');
            elsif fetch = '1' and ready_i = '1' then
                state <= BUSY;
            elsif fetch = '1' then
                state   <= PEND;
                adr_reg <= adr_i;
            elsif state = PEND and ready_i = '1' then
                state <= BUSY;
            elsif state = BUSY and rx_valid_i = '1' then
                state <= IDLE;
            end if;
        end if;
    end process fsm_proc;

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

    start_o   <= '1' when fetch = '1' or state = PEND else '0';
    tx_data_o <= CMD_READ & adr & "00" & (SOC_DATA_WIDTH-1 downto 0 => '0');
    ack_o     <= '1' when state = BUSY and rx_valid_i = '1' else '0';
    err_o     <= err_reg;
    dat_o     <= rx_data_i(7 downto 0) & rx_data_i(15 downto 8) & rx_data_i(23 downto 16) & rx_data_i(31 downto 24);

end architecture rtl;
