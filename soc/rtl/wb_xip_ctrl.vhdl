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
        tx_data_o  : out std_logic_vector(7 downto 0);
        tx_last_o  : out std_logic;
        tx_valid_o : out std_logic;
        tx_ready_i : in  std_logic;
        rx_data_i  : in  std_logic_vector(7 downto 0);
        rx_valid_i : in  std_logic
    );
end entity wb_xip_ctrl;

architecture rtl of wb_xip_ctrl is

    constant CMD_READ : std_logic_vector(7 downto 0) := x"03";

    type state_t is (IDLE, SEND, RECV);

    signal state    : state_t;
    signal req      : std_logic;
    signal adr_reg  : std_logic_vector(XIP_ADDR_WIDTH-1 downto 0);
    signal tx_idx   : natural range 0 to 7;
    signal rx_idx   : natural range 0 to 7;
    signal tx_data  : std_logic_vector(7 downto 0);
    signal tx_valid : std_logic;
    signal data_reg : std_logic_vector(23 downto 0);
    signal ack      : std_logic;
    signal err_reg  : std_logic;

begin

    req      <= cyc_i and stb_i;
    tx_valid <= '1' when (state = IDLE and req = '1' and dis_i = '0') or state = SEND else '0';

    tx_proc: process(tx_idx, adr_reg)
    begin
        case tx_idx is
            when 0      => tx_data <= CMD_READ;
            when 1      => tx_data <= adr_reg(23 downto 16);
            when 2      => tx_data <= adr_reg(15 downto 8);
            when 3      => tx_data <= adr_reg(7 downto 0);
            when others => tx_data <= (others => '0');
        end case;
    end process tx_proc;

    ack <= '1' when state = RECV and rx_valid_i = '1' and rx_idx = 7 else '0';

    ctrl_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state    <= IDLE;
                adr_reg  <= (others => '0');
                tx_idx   <= 0;
                rx_idx   <= 0;
                data_reg <= (others => '0');
                err_reg  <= '0';
            else
                err_reg <= '0';
                case state is
                    when IDLE =>
                        if req = '1' and dis_i = '1' then
                            err_reg <= '1';
                        elsif req = '1' then
                            adr_reg <= adr_i & "00";
                            rx_idx  <= 0;
                            state   <= SEND;
                            if tx_ready_i = '1' then
                                tx_idx <= 1;
                            else
                                tx_idx <= 0;
                            end if;
                        end if;
                    when SEND =>
                        if tx_ready_i = '1' then
                            if tx_idx = 7 then
                                state <= RECV;
                            else
                                tx_idx <= tx_idx + 1;
                            end if;
                        end if;
                    when RECV =>
                        if ack = '1' then
                            state  <= IDLE;
                            tx_idx <= 0;
                        end if;
                end case;
                if rx_valid_i = '1' and state /= IDLE then
                    if rx_idx /= 7 then
                        rx_idx <= rx_idx + 1;
                    end if;
                    data_reg <= rx_data_i & data_reg(23 downto 8);
                end if;
            end if;
        end if;
    end process ctrl_proc;

    tx_data_o  <= tx_data;
    tx_last_o  <= '1' when tx_idx = 7 else '0';
    tx_valid_o <= tx_valid;
    ack_o      <= ack;
    err_o      <= err_reg;
    dat_o      <= rx_data_i & data_reg;

end architecture rtl;
