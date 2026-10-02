----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: SPI slave (mode 0, byte interface)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_slave is
    port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        sck_i      : in  std_logic;
        cs_n_i     : in  std_logic;
        mosi_i     : in  std_logic;
        miso_o     : out std_logic;
        active_o   : out std_logic;
        rx_data_o  : out std_logic_vector(7 downto 0);
        rx_valid_o : out std_logic;
        tx_data_i  : in  std_logic_vector(7 downto 0);
        tx_load_o  : out std_logic
    );
end entity spi_slave;

architecture rtl of spi_slave is

    signal sck_s  : std_logic_vector(2 downto 0);
    signal cs_s   : std_logic_vector(1 downto 0);
    signal mosi_s : std_logic_vector(1 downto 0);

    signal cs_act   : std_logic;
    signal sck_rise : std_logic;
    signal sck_fall : std_logic;

    signal bit_cnt : unsigned(2 downto 0);
    signal rx_sh   : std_logic_vector(6 downto 0);
    signal tx_sh   : std_logic_vector(7 downto 0);
    signal tx_load : std_logic;

begin

    sync_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                sck_s  <= (others => '0');
                cs_s   <= (others => '1');
                mosi_s <= (others => '0');
            else
                sck_s  <= sck_s(1 downto 0) & sck_i;
                cs_s   <= cs_s(0) & cs_n_i;
                mosi_s <= mosi_s(0) & mosi_i;
            end if;
        end if;
    end process sync_proc;

    cs_act   <= not cs_s(1);
    sck_rise <= sck_s(1) and not sck_s(2);
    sck_fall <= sck_s(2) and not sck_s(1);
    tx_load  <= '1' when cs_act = '1' and sck_fall = '1' and bit_cnt = 0 else '0';

    shift_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                bit_cnt <= (others => '0');
                rx_sh   <= (others => '0');
                tx_sh   <= (others => '0');
            elsif cs_act = '0' then
                bit_cnt <= (others => '0');
                tx_sh   <= (others => '0');
            else
                if sck_rise = '1' then
                    rx_sh   <= rx_sh(5 downto 0) & mosi_s(1);
                    bit_cnt <= bit_cnt + 1;
                end if;
                if sck_fall = '1' then
                    if tx_load = '1' then
                        tx_sh <= tx_data_i;
                    else
                        tx_sh <= tx_sh(6 downto 0) & '0';
                    end if;
                end if;
            end if;
        end if;
    end process shift_proc;

    miso_o     <= tx_sh(7);
    active_o   <= cs_act;
    rx_data_o  <= rx_sh & mosi_s(1);
    rx_valid_o <= '1' when cs_act = '1' and sck_rise = '1' and bit_cnt = 7 else '0';
    tx_load_o  <= tx_load;

end architecture rtl;
