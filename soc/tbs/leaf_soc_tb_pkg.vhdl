library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.uart_tb_pkg.all;

package leaf_soc_tb_pkg is

    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

    procedure load_bin_file (
        constant path : in string;
        variable data : out byte_array_t;
        variable size : out natural
    );

    function calc_crc (
        data       : std_logic_vector;
        crc_in     : std_logic_vector;
        polynomial : std_logic_vector
    ) return std_logic_vector;

    procedure leaf_soc_send_program (
        signal tx : out std_logic;
        signal rx_data : in std_logic_vector(7 downto 0);
        constant program : in string
    );

end package leaf_soc_tb_pkg;

package body leaf_soc_tb_pkg is

    procedure load_bin_file (
        constant path : in string;
        variable data : out byte_array_t;
        variable size : out natural
    ) is
        type bin_file_t is file of character;
        file bin_file : bin_file_t;
        variable byte : character;
        variable addr : natural;
    begin
        file_open(bin_file, path, read_mode);
        addr := 0;
        while not endfile(bin_file) loop
            read(bin_file, byte);
            data(addr) := std_logic_vector(to_unsigned(character'pos(byte), 8));
            addr := addr + 1;
        end loop;
        file_close(bin_file);
        size := addr;
    end procedure load_bin_file;

    function calc_crc (
        data       : std_logic_vector;
        crc_in     : std_logic_vector;
        polynomial : std_logic_vector
    ) return std_logic_vector is
        variable crc : std_logic_vector(crc_in'range) := crc_in;
    begin
        for i in data'high downto data'low loop
            if crc(crc'high) = '1' then
                crc := (crc(crc'high - 1 downto 0) & data(i)) xor polynomial;
            else
                crc := (crc(crc'high - 1 downto 0) & data(i));
            end if;
        end loop;
        return crc;
    end function calc_crc;

    procedure leaf_soc_send_program (
        signal tx : out std_logic;
        signal rx_data : in std_logic_vector(7 downto 0);
        constant program : in string
    ) is

        constant RAM_JUMP_CMD : std_logic_vector(7 downto 0) := x"4A";
        constant RAM_LOAD_CMD : std_logic_vector(7 downto 0) := x"4C";

        constant ACK : std_logic_vector(7 downto 0) := x"06";
        constant NAK : std_logic_vector(7 downto 0) := x"15";

        constant MAX_PROGRAM_SIZE : natural := 64 * 1024;

        variable program_data : byte_array_t(0 to MAX_PROGRAM_SIZE - 1) := (others => x"00");
        variable program_size : natural := 0;

        constant crc_polynomial : std_logic_vector := x"07";

        variable crc : std_logic_vector(7 downto 0) := (others => '0');
        variable byte : std_logic_vector(7 downto 0) := (others => '0');

    begin

        load_bin_file(program, program_data, program_size);

        uart_transmit(tx, RAM_LOAD_CMD);
        wait until rx_data = ACK for 20 us;

        for i in 0 to 3 loop
            byte := std_logic_vector(to_unsigned(program_size / (2**(8*i)), 8));
            uart_transmit(tx, byte);
            crc := calc_crc(byte, crc, crc_polynomial);
        end loop;
        crc := calc_crc(x"00", crc, crc_polynomial);
        uart_transmit(tx, crc);
        wait until rx_data = ACK for 20 us;

        crc := x"00";
        for i in 0 to program_size-1 loop
            byte := program_data(i);
            uart_transmit(tx, byte);
            crc := calc_crc(byte, crc, crc_polynomial);
            if (i + 1) mod 1024 = 0 then
                crc := calc_crc(x"00", crc, crc_polynomial);
                uart_transmit(tx, crc);
                wait until rx_data = ACK for 20 us;
                crc := x"00";
            end if;
        end loop;

        if program_size mod 1024 /= 0 then
            crc := calc_crc(x"00", crc, crc_polynomial);
            uart_transmit(tx, crc);
            wait until rx_data = ACK for 20 us;
        end if;

        uart_transmit(tx, RAM_JUMP_CMD);
        wait until rx_data = ACK for 20 us;

    end procedure leaf_soc_send_program;

end package body leaf_soc_tb_pkg;