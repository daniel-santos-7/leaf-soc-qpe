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
        clk_i     : in  std_logic;
        rst_i     : in  std_logic;
        cyc_i     : in  std_logic;
        stb_i     : in  std_logic;
        adr_i     : in  std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
        ack_o     : out std_logic;
        dat_o     : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        spi_clk   : out std_logic;
        spi_mosi  : out std_logic;
        spi_miso  : in  std_logic;
        spi_cs_n  : out std_logic
    );
end entity wb_xip_ctrl;

architecture rtl of wb_xip_ctrl is

    type state_t is (IDLE, SHIFT, DONE);

    signal state    : state_t;
    signal sck      : std_logic;
    signal bit_cnt  : natural range 0 to 63;
    signal cmd_word : std_logic_vector(31 downto 0);
    signal tx_shift : std_logic_vector(31 downto 0);
    signal rx_shift : std_logic_vector(31 downto 0);

begin

    cmd_word <= x"03" & adr_i & "00";

    xip_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state    <= IDLE;
                sck      <= '0';
                bit_cnt  <= 0;
                tx_shift <= (others => '0');
                rx_shift <= (others => '0');
                spi_cs_n <= '1';
                spi_mosi <= '0';
            else
                case state is
                    when IDLE =>
                        if cyc_i = '1' and stb_i = '1' then
                            spi_cs_n <= '0';
                            spi_mosi <= cmd_word(31);
                            tx_shift <= cmd_word(30 downto 0) & '0';
                            bit_cnt  <= 0;
                            state    <= SHIFT;
                        end if;

                    when SHIFT =>
                        if sck = '0' then
                            sck      <= '1';
                            rx_shift <= rx_shift(30 downto 0) & spi_miso;
                        else
                            sck <= '0';
                            if bit_cnt = 63 then
                                spi_cs_n <= '1';
                                spi_mosi <= '0';
                                state    <= DONE;
                            else
                                spi_mosi <= tx_shift(31);
                                tx_shift <= tx_shift(30 downto 0) & '0';
                                bit_cnt  <= bit_cnt + 1;
                            end if;
                        end if;

                    when DONE =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process xip_proc;

    spi_clk <= sck;
    dat_o   <= rx_shift(7 downto 0) & rx_shift(15 downto 8) & rx_shift(23 downto 16) & rx_shift(31 downto 24);
    ack_o   <= '1' when state = DONE else '0';

end architecture rtl;
