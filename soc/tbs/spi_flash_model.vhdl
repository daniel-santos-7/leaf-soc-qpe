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
        spi_clk  : in  std_logic;
        spi_mosi : in  std_logic;
        spi_miso : out std_logic;
        spi_cs_n : in  std_logic
    );
end entity spi_flash_model;

architecture sim of spi_flash_model is

    constant MEM_BITS : natural := 19;

    type mem_array_t is array (0 to 2**MEM_BITS-1) of std_logic_vector(7 downto 0);
    signal memory : mem_array_t := (others => (others => '0'));

    type state_t is (CMD, ADDR, DATA, IGNORE);
    signal state : state_t;

    signal bit_cnt  : natural range 0 to 23;
    signal cmd_reg  : std_logic_vector(6 downto 0);
    signal addr_reg : std_logic_vector(22 downto 0);
    signal base     : unsigned(MEM_BITS-1 downto 0);

    signal out_bit  : natural range 0 to 7;
    signal out_byte : unsigned(MEM_BITS-1 downto 0);

begin

    init_proc: process
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
        wait;
    end process init_proc;

    rise_proc: process(spi_clk, spi_cs_n)
    begin
        if spi_cs_n = '1' then
            state   <= CMD;
            bit_cnt <= 0;
        elsif rising_edge(spi_clk) then
            case state is
                when CMD =>
                    cmd_reg <= cmd_reg(5 downto 0) & spi_mosi;
                    if bit_cnt = 7 then
                        bit_cnt <= 0;
                        if (cmd_reg & spi_mosi) = x"03" then
                            state <= ADDR;
                        else
                            state <= IGNORE;
                        end if;
                    else
                        bit_cnt <= bit_cnt + 1;
                    end if;

                when ADDR =>
                    addr_reg <= addr_reg(21 downto 0) & spi_mosi;
                    if bit_cnt = 23 then
                        base  <= unsigned(addr_reg(MEM_BITS-2 downto 0) & spi_mosi);
                        state <= DATA;
                    else
                        bit_cnt <= bit_cnt + 1;
                    end if;

                when DATA | IGNORE =>
                    null;
            end case;
        end if;
    end process rise_proc;

    fall_proc: process(spi_clk, spi_cs_n)
        variable byte : std_logic_vector(7 downto 0);
    begin
        if spi_cs_n = '1' then
            spi_miso <= 'Z';
            out_bit  <= 0;
            out_byte <= (others => '0');
        elsif falling_edge(spi_clk) then
            if state = DATA then
                byte     := memory(to_integer(base + out_byte));
                spi_miso <= byte(7 - out_bit);
                if out_bit = 7 then
                    out_bit  <= 0;
                    out_byte <= out_byte + 1;
                else
                    out_bit <= out_bit + 1;
                end if;
            end if;
        end if;
    end process fall_proc;

end architecture sim;
