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
        stall_o    : out std_logic;
        dat_o      : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        dis_i      : in  std_logic;
        tx_valid_o : out std_logic;
        tx_ready_i : in  std_logic;
        tx_data_o  : out std_logic_vector(SPI_WIDTH-1 downto 0);
        tx_bits_o  : out std_logic_vector(SPI_CNT_BITS-1 downto 0);
        rx_data_i  : in  std_logic_vector(SPI_WIDTH-1 downto 0);
        rx_valid_i : in  std_logic
    );
end entity wb_xip_ctrl;

architecture rtl of wb_xip_ctrl is

    constant CMD_READ : std_logic_vector(7 downto 0) := x"03";

    type state_t is (IDLE, SEND, BUSY, HOLD);

    signal state_reg    : state_t;
    signal adr_reg      : std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
    signal ack_reg      : std_logic;
    signal err_reg      : std_logic;
    signal stall_reg    : std_logic;
    signal tx_valid_reg : std_logic;
    signal hold_cnt_reg : natural range 0 to CS_HIGH_CYCLES;

    signal req          : std_logic;

begin

    assert CS_HIGH_CYCLES >= 2 report "XIP: CS_HIGH_CYCLES must be at least 2." severity failure;

    req <= cyc_i and stb_i;

    fsm_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state_reg    <= IDLE;
                adr_reg      <= (others => '0');
                ack_reg      <= '0';
                err_reg      <= '0';
                stall_reg    <= '0';
                tx_valid_reg <= '0';
            else
                case state_reg is
                    when IDLE =>
                        ack_reg <= '0';
                        if req = '1' then
                            if dis_i = '0' then
                                state_reg    <= SEND;
                                adr_reg      <= adr_i;
                                err_reg      <= '0';
                                stall_reg    <= '1';
                                tx_valid_reg <= '1';
                            else
                                err_reg <= '1';
                            end if;
                        else
                            err_reg <= '0';
                        end if;
                    when SEND =>
                        if tx_ready_i = '1' then
                            state_reg    <= BUSY;
                            tx_valid_reg <= '0';
                        end if;
                    when BUSY =>
                        if rx_valid_i = '1' then
                            ack_reg <= '1';
                            if CS_HIGH_CYCLES > 4 then
                                state_reg <= HOLD;
                            else
                                state_reg <= IDLE;
                                stall_reg <= '0';
                            end if;
                        end if;
                    when HOLD =>
                        ack_reg <= '0';
                        if hold_cnt_reg = CS_HIGH_CYCLES-5 then
                            state_reg <= IDLE;
                            stall_reg <= '0';
                        end if;
                end case;
            end if;
        end if;
    end process fsm_proc;

    hold_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                hold_cnt_reg <= 0;
            elsif state_reg = HOLD then
                hold_cnt_reg <= hold_cnt_reg + 1;
            else
                hold_cnt_reg <= 0;
            end if;
        end if;
    end process hold_proc;

    tx_valid_o <= tx_valid_reg;
    tx_data_o  <= CMD_READ & adr_reg & "00" & (SOC_DATA_WIDTH-1 downto 0 => '0');
    tx_bits_o  <= std_logic_vector(to_unsigned(SPI_WIDTH, SPI_CNT_BITS));
    ack_o      <= ack_reg;
    err_o      <= err_reg;
    stall_o    <= stall_reg;
    dat_o      <= rx_data_i(7 downto 0) & rx_data_i(15 downto 8) & rx_data_i(23 downto 16) & rx_data_i(31 downto 24);

end architecture rtl;
