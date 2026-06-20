----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: SPI flash simulation model
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity spi_flash_model is
    generic (
        INIT_FILE : string := ""
    );
    port (
        clk_i    : in  std_logic;
        spi_clk  : in  std_logic;
        spi_mosi : in  std_logic;
        spi_miso : out std_logic;
        spi_cs_n : in  std_logic
    );
end entity spi_flash_model;

architecture sim of spi_flash_model is

    type mem_array_t is array (0 to 16#7FFFF#) of std_logic_vector(7 downto 0);
    signal memory : mem_array_t := (others => (others => '0'));

    type state_t is (IDLE, CAPTURE_ADDR, READ_DATA);
    signal state : state_t;

    signal shift_reg : std_logic_vector(7 downto 0);
    signal bit_cnt   : natural range 0 to 7;
    signal addr_reg  : std_logic_vector(23 downto 0);
    signal byte_cnt  : natural range 0 to 2;
    signal data_byte : std_logic_vector(7 downto 0);
    signal data_bit_cnt : natural range 0 to 7;

    signal spi_clk_prev : std_logic;
    signal spi_clk_rise : std_logic;
    signal spi_clk_fall : std_logic;

    signal mem_init_done : boolean := false;

begin

    -- SPI clock edge detection
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            spi_clk_prev <= spi_clk;
        end if;
    end process;

    spi_clk_rise <= spi_clk and not spi_clk_prev;
    spi_clk_fall <= not spi_clk and spi_clk_prev;

    -- Memory initialization
    process
        type bin_file_t is file of character;
        file f : bin_file_t;
        variable byte : character;
        variable addr : natural := 0;
    begin
        if INIT_FILE /= "" then
            file_open(f, INIT_FILE, read_mode);
            while not endfile(f) loop
                read(f, byte);
                memory(addr) <= std_logic_vector(to_unsigned(character'pos(byte), 8));
                addr := addr + 1;
            end loop;
            file_close(f);
        end if;
        mem_init_done <= true;
        wait;
    end process;

    -- SPI flash state machine
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if spi_cs_n = '1' or not mem_init_done then
                state <= IDLE;
                bit_cnt <= 0;
                byte_cnt <= 0;
                shift_reg <= (others => '0');
                addr_reg <= (others => '0');
                spi_miso <= 'Z';
            else
                case state is
                    when IDLE =>
                        if spi_clk_rise = '1' then
                            shift_reg <= shift_reg(6 downto 0) & spi_mosi;
                            bit_cnt <= bit_cnt + 1;
                            if bit_cnt = 7 then
                                if shift_reg(6 downto 0) & spi_mosi = x"03" then
                                    state <= CAPTURE_ADDR;
                                    byte_cnt <= 0;
                                else
                                    state <= IDLE;
                                end if;
                                bit_cnt <= 0;
                            end if;
                        end if;

                    when CAPTURE_ADDR =>
                        if spi_clk_rise = '1' then
                            addr_reg <= addr_reg(22 downto 0) & spi_mosi;
                            bit_cnt <= bit_cnt + 1;
                            if bit_cnt = 7 then
                                byte_cnt <= byte_cnt + 1;
                                bit_cnt <= 0;
                                if byte_cnt = 2 then
                                    state <= READ_DATA;
                                    data_bit_cnt <= 0;
                                    data_byte <= memory(to_integer(unsigned(addr_reg(22 downto 0) & spi_mosi)));
                                end if;
                            end if;
                        end if;

                    when READ_DATA =>
                        if spi_clk_fall = '1' then
                            spi_miso <= data_byte(7);
                            data_byte <= data_byte(6 downto 0) & '0';
                            data_bit_cnt <= data_bit_cnt + 1;
                            if data_bit_cnt = 7 then
                                if byte_cnt < 3 then
                                    addr_reg <= std_logic_vector(unsigned(addr_reg) + 1);
                                    data_byte <= memory(to_integer(unsigned(addr_reg)));
                                    data_bit_cnt <= 0;
                                else
                                    state <= IDLE;
                                end if;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture sim;