library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.uart_tb_pkg.all;

package leaf_soc_tb_pkg is

    constant PROGRAM_FILE : string := "work/program.bin";

    type byte_array_t is array (natural range <>) of std_logic_vector(7 downto 0);

    procedure load_bin_file (
        constant path : in string;
        variable data : out byte_array_t;
        variable size : out natural
    );

    procedure init_mem (
        constant file_name : in string;
        constant mem_size  : in natural;
        variable lane0 : inout byte_array_t;
        variable lane1 : inout byte_array_t;
        variable lane2 : inout byte_array_t;
        variable lane3 : inout byte_array_t
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

    use std.textio.all;

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

    procedure init_mem (
        constant file_name : in string;
        constant mem_size  : in natural;
        variable lane0 : inout byte_array_t;
        variable lane1 : inout byte_array_t;
        variable lane2 : inout byte_array_t;
        variable lane3 : inout byte_array_t
    ) is
        type char_file is file of character;
        file bin_file : char_file;
        variable byte : character;
        variable addr : natural;
        variable status : file_open_status;
    begin
        if file_name /= "" then
            file_open(status, bin_file, file_name, read_mode);
            if status = open_ok then
                addr := 0;
                while not endfile(bin_file) and addr < mem_size loop
                    read(bin_file, byte);
                    case addr mod 4 is
                        when 0 => lane0(addr / 4) := std_logic_vector(to_unsigned(character'pos(byte), 8));
                        when 1 => lane1(addr / 4) := std_logic_vector(to_unsigned(character'pos(byte), 8));
                        when 2 => lane2(addr / 4) := std_logic_vector(to_unsigned(character'pos(byte), 8));
                        when 3 => lane3(addr / 4) := std_logic_vector(to_unsigned(character'pos(byte), 8));
                        when others => null;
                    end case;
                    addr := addr + 1;
                end loop;
                file_close(bin_file);
                report "init_mem: loaded " & integer'image(addr) & " bytes from " & file_name;
            end if;
        end if;
    end procedure init_mem;

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
        report "Loaded " & integer'image(program_size) & " bytes from " & program;

        report "Sending RAM_LOAD_CMD (0x4C)...";
        uart_transmit(tx, RAM_LOAD_CMD);
        wait until rx_data = ACK for 100 us;
        if rx_data = ACK then
            report "ACK received after RAM_LOAD_CMD at " & time'image(now);
        else
            report "ERROR: No ACK after RAM_LOAD_CMD" severity failure;
        end if;

        report "Sending size: " & integer'image(program_size) & " bytes";
        for i in 0 to 3 loop
            byte := std_logic_vector(to_unsigned(program_size / (2**(8*i)), 8));
            uart_transmit(tx, byte);
            crc := calc_crc(byte, crc, crc_polynomial);
        end loop;
        crc := calc_crc(x"00", crc, crc_polynomial);
        report "Size CRC: " & integer'image(to_integer(unsigned(crc)));
        uart_transmit(tx, crc);
        wait until rx_data = ACK for 100 us;
        if rx_data = ACK then
            report "ACK received after size+CRC at " & time'image(now);
        else
            report "ERROR: No ACK after size+CRC" severity failure;
        end if;

        report "Sending " & integer'image(program_size) & " program bytes...";
        crc := x"00";
        for i in 0 to program_size-1 loop
            byte := program_data(i);
            uart_transmit(tx, byte);
            crc := calc_crc(byte, crc, crc_polynomial);
            if (i + 1) mod 1024 = 0 then
                crc := calc_crc(x"00", crc, crc_polynomial);
                report "Progress: " & integer'image(i+1) & "/" & integer'image(program_size) & " bytes, CRC: " & integer'image(to_integer(unsigned(crc)));
                uart_transmit(tx, crc);
                wait until rx_data = ACK for 100 us;
                if rx_data = ACK then
                    report "ACK received after 1024-byte block at " & time'image(now);
                else
                    report "ERROR: No ACK after 1024-byte block" severity failure;
                end if;
                crc := x"00";
            end if;
        end loop;

        if program_size mod 1024 /= 0 then
            crc := calc_crc(x"00", crc, crc_polynomial);
            report "Final CRC: " & integer'image(to_integer(unsigned(crc)));
            uart_transmit(tx, crc);
            wait until rx_data = ACK for 100 us;
            if rx_data = ACK then
                report "ACK received after final CRC at " & time'image(now);
            else
                report "ERROR: No ACK after final CRC" severity failure;
            end if;
        end if;

        report "Sending RAM_JUMP_CMD (0x4A)...";
        uart_transmit(tx, RAM_JUMP_CMD);
        wait until rx_data = ACK for 100 us;
        if rx_data = ACK then
            report "ACK received after RAM_JUMP_CMD at " & time'image(now);
        else
            report "ERROR: No ACK after RAM_JUMP_CMD" severity failure;
        end if;

        report "Program loaded and started!";

    end procedure leaf_soc_send_program;

end package body leaf_soc_tb_pkg;