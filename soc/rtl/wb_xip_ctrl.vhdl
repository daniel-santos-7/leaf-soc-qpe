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
    port (
        clk_i     : in  std_logic;
        rst_i     : in  std_logic;
        cyc_i     : in  std_logic;
        stb_i     : in  std_logic;
        we_i      : in  std_logic;
        sel_i     : in  std_logic_vector(3 downto 0);
        adr_i     : in  std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
        dat_i     : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ack_o     : out std_logic;
        err_o     : out std_logic;
        dat_o     : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        spi_clk   : out std_logic;
        spi_mosi  : out std_logic;
        spi_miso  : in  std_logic;
        spi_cs_n  : out std_logic
    );
end entity wb_xip_ctrl;

architecture rtl of wb_xip_ctrl is

    type state_t is (IDLE, CS_SETUP, TRANSFER, CS_HOLD, DONE);
    
    signal state : state_t;

    signal sck_phase : std_logic;
    signal bit_cnt   : natural range 0 to 63;
    signal tx_shift  : std_logic_vector(31 downto 0);
    signal rx_shift  : std_logic_vector(31 downto 0);
    signal flash_addr : std_logic_vector(23 downto 0);

begin

    flash_addr <= adr_i & "00";

    -- SCK generation (sysclk/2)
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' or state = IDLE then
                sck_phase <= '0';
            else
                sck_phase <= not sck_phase;
            end if;
        end if;
    end process;

    spi_clk <= sck_phase when state = TRANSFER else '0';

    -- Main state machine
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state      <= IDLE;
                bit_cnt    <= 0;
                tx_shift   <= (others => '0');
                rx_shift   <= (others => '0');
                spi_cs_n   <= '1';
                spi_mosi   <= '0';
            else
                case state is
                    when IDLE =>
                        spi_cs_n <= '1';
                        if cyc_i = '1' and stb_i = '1' then
                            if we_i = '1' then
                                null;
                            else
                                tx_shift <= x"03" & flash_addr;
                                rx_shift <= (others => '0');
                                bit_cnt  <= 0;
                                spi_cs_n <= '0';
                                state    <= CS_SETUP;
                            end if;
                        end if;

                    when CS_SETUP =>
                        state <= TRANSFER;

                    when TRANSFER =>
                        if sck_phase = '0' then
                            spi_mosi <= tx_shift(31);
                            tx_shift <= tx_shift(30 downto 0) & '0';
                        else
                            if bit_cnt >= 32 then
                                rx_shift <= rx_shift(30 downto 0) & spi_miso;
                            end if;
                            bit_cnt <= bit_cnt + 1;
                        end if;

                        if bit_cnt = 63 and sck_phase = '1' then
                            state <= CS_HOLD;
                        end if;

                    when CS_HOLD =>
                        spi_cs_n <= '1';
                        state    <= DONE;

                    when DONE =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    dat_o <= rx_shift(7 downto 0) & rx_shift(15 downto 8) & rx_shift(23 downto 16) & rx_shift(31 downto 24);
    ack_o <= '1' when state = DONE else '0';
    err_o <= '1' when cyc_i = '1' and stb_i = '1' and we_i = '1' else '0';

end architecture rtl;