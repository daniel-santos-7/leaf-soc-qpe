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
        CS_HIGH_CYCLES : positive := 2;
        SCK_DIV        : positive := 1
    );
    port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        cyc_a_i    : in  std_logic;
        stb_a_i    : in  std_logic;
        we_a_i     : in  std_logic;
        sel_a_i    : in  std_logic_vector(3 downto 0);
        adr_a_i    : in  std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
        dat_a_i    : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ack_a_o    : out std_logic;
        err_a_o    : out std_logic;
        stall_a_o  : out std_logic;
        dat_a_o    : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        cyc_b_i    : in  std_logic;
        stb_b_i    : in  std_logic;
        adr_b_i    : in  std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
        ack_b_o    : out std_logic;
        err_b_o    : out std_logic;
        stall_b_o  : out std_logic;
        dat_b_o    : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        en_o       : out std_logic;
        role_ack_i : in  std_logic;
        sck_div_o  : out std_logic_vector(SPI_DIV_BITS-1 downto 0);
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
    constant CFG_ADR  : std_logic_vector(XIP_ADDR_WIDTH-1 downto 2) := (others => '1');

    type state_t is (IDLE, ERR, SEND, BUSY, ACK, HOLD);

    signal state_reg    : state_t;
    signal adr_reg      : std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
    signal ack_b_reg    : std_logic;
    signal err_b_reg    : std_logic;
    signal stall_b_reg  : std_logic;
    signal tx_valid_reg : std_logic;
    signal hold_cnt_reg : unsigned(7 downto 0);

    signal ack_a_reg    : std_logic;
    signal err_a_reg    : std_logic;
    signal cs_high_reg  : unsigned(7 downto 0);
    signal en_req_reg   : std_logic;
    signal en_reg       : std_logic;
    signal sck_div_reg  : std_logic_vector(SPI_DIV_BITS-1 downto 0);

    signal req_a        : std_logic;
    signal hit_a        : std_logic;
    signal req_b        : std_logic;
    signal hold_end     : std_logic;

begin

    assert CS_HIGH_CYCLES <= 255 report "XIP: CS_HIGH_CYCLES must fit in 8 bits." severity failure;
    assert SCK_DIV <= 2**SPI_DIV_BITS report "XIP: SCK_DIV-1 must fit in SPI_DIV_BITS bits." severity failure;

    req_a <= cyc_a_i and stb_a_i;
    hit_a <= '1' when adr_a_i = CFG_ADR else '0';
    req_b <= cyc_b_i and stb_b_i;

    hold_end <= '1' when hold_cnt_reg >= cs_high_reg else '0';

    cfg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_a_reg   <= '0';
                err_a_reg   <= '0';
                cs_high_reg <= to_unsigned(CS_HIGH_CYCLES, 8);
                en_req_reg  <= '0';
                sck_div_reg <= std_logic_vector(to_unsigned(SCK_DIV-1, SPI_DIV_BITS));
            elsif req_a = '1' then
                if hit_a = '1' then
                    ack_a_reg <= '1';
                    err_a_reg <= '0';
                    if we_a_i = '1' and sel_a_i(0) = '1' then
                        en_req_reg <= dat_a_i(0);
                    end if;
                    if we_a_i = '1' and sel_a_i(1) = '1' then
                        cs_high_reg <= unsigned(dat_a_i(15 downto 8));
                    end if;
                    if we_a_i = '1' and sel_a_i(2) = '1' then
                        sck_div_reg <= dat_a_i(16+SPI_DIV_BITS-1 downto 16);
                    end if;
                else
                    ack_a_reg <= '0';
                    err_a_reg <= '1';
                end if;
            else
                ack_a_reg <= '0';
                err_a_reg <= '0';
            end if;
        end if;
    end process cfg_proc;

    fsm_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state_reg    <= IDLE;
                adr_reg      <= (others => '0');
                en_reg       <= '0';
                ack_b_reg    <= '0';
                err_b_reg    <= '0';
                stall_b_reg  <= '0';
                tx_valid_reg <= '0';
            else
                case state_reg is
                    when IDLE =>
                        if req_b = '1' then
                            if en_reg = '1' and role_ack_i = '1' then
                                state_reg    <= SEND;
                                adr_reg      <= adr_b_i;
                                stall_b_reg  <= '1';
                                tx_valid_reg <= '1';
                            else
                                state_reg   <= ERR;
                                err_b_reg   <= '1';
                                stall_b_reg <= '1';
                            end if;
                        else
                            en_reg <= en_req_reg;
                        end if;
                    when ERR =>
                        state_reg   <= IDLE;
                        err_b_reg   <= '0';
                        stall_b_reg <= '0';
                    when SEND =>
                        if tx_ready_i = '1' then
                            state_reg    <= BUSY;
                            tx_valid_reg <= '0';
                        end if;
                    when BUSY =>
                        if rx_valid_i = '1' then
                            state_reg <= ACK;
                            ack_b_reg <= '1';
                        end if;
                    when ACK =>
                        ack_b_reg <= '0';
                        if cs_high_reg > 5 then
                            state_reg <= HOLD;
                        else
                            state_reg   <= IDLE;
                            stall_b_reg <= '0';
                        end if;
                    when HOLD =>
                        if hold_end = '1' then
                            state_reg   <= IDLE;
                            stall_b_reg <= '0';
                        end if;
                end case;
            end if;
        end if;
    end process fsm_proc;

    hold_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                hold_cnt_reg <= to_unsigned(6, 8);
            elsif state_reg = HOLD then
                hold_cnt_reg <= hold_cnt_reg + 1;
            else
                hold_cnt_reg <= to_unsigned(6, 8);
            end if;
        end if;
    end process hold_proc;

    ack_a_o    <= ack_a_reg;
    err_a_o    <= err_a_reg;
    stall_a_o  <= '0';
    dat_a_o    <= (SOC_DATA_WIDTH-1 downto 16+SPI_DIV_BITS => '0') & sck_div_reg & std_logic_vector(cs_high_reg) & "000000" & role_ack_i & en_req_reg;
    ack_b_o    <= ack_b_reg;
    err_b_o    <= err_b_reg;
    stall_b_o  <= stall_b_reg;
    dat_b_o    <= rx_data_i(7 downto 0) & rx_data_i(15 downto 8) & rx_data_i(23 downto 16) & rx_data_i(31 downto 24);
    en_o       <= en_reg;
    sck_div_o  <= sck_div_reg;
    tx_valid_o <= tx_valid_reg;
    tx_data_o  <= CMD_READ & adr_reg & "00" & (SOC_DATA_WIDTH-1 downto 0 => '0');
    tx_bits_o  <= std_logic_vector(to_unsigned(SPI_WIDTH, SPI_CNT_BITS));

end architecture rtl;
