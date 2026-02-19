library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package leaf_soc_tb_pkg is

    constant CLK_PERIOD : time := 20 ns;

    constant MEM_SIZE : natural := 4 * 1024;

    type byte_array is array (0 to MEM_SIZE-1) of std_logic_vector(7 downto 0);

    impure function load_mem_data(constant file_path : string) return byte_array;

    constant UART_9600_BAUD_RATE : time := 104167 ns;

    constant UART_115200_BAUD_RATE : time := 8680 ns;

    procedure uart_tx(
        constant baud : time;
        constant data : std_logic_vector(7 downto 0);
        signal tx : out std_logic
    );

    procedure uart_rx(
        constant baud : time;
        signal data : out std_logic_vector(7 downto 0);
        signal rx : in std_logic
    );

    component xip_ctrl is
        port (
            clk   : in  std_logic;
            rst   : in  std_logic;
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            sel_i : in  std_logic_vector(3  downto 0);
            adr_i : in  std_logic_vector(31 downto 0);
            dat_i : in  std_logic_vector(31 downto 0);
            ack_o : out std_logic;
            err_o : out std_logic;
            dat_o : out std_logic_vector(31 downto 0)
        );
    end component xip_ctrl;

    -- constant BITS       : natural := 24;
    -- constant MEM_SIZE   : natural := 2**BITS;
    -- constant UART_BAUD  : natural := 434;
    -- constant WM_CMD     : std_logic_vector(7 downto 0) := x"31";

    -- ld_program: process
    --     variable byte  : byte_type;
    --     variable addr  : integer;
    --     variable size  : std_logic_vector(31 downto 0);
    --     variable frame : std_logic_vector(9 downto 0);
    -- begin
    --     rx <= '1';
    --     wait for 25*CLK_PERIOD;

    --     file_open(bin, PROGRAM);
    --     addr := 0;
    --     while not endfile(bin) loop
    --         read(bin, byte);
    --         mem(addr) := std_logic_vector(to_unsigned(byte_type'pos(byte), 8));
    --         addr := addr + 1;
    --     end loop;
    --     file_close(bin);

    --     frame := '1' & WM_CMD & '0';
    --     for i in 0 to 9 loop
    --         rx <= frame(i);
    --         wait for UART_BAUD*CLK_PERIOD;
    --     end loop;

    --     size := std_logic_vector(to_unsigned(addr, 32));

    --     frame := '1' & size(31 downto 24) & '0';
    --     for i in 0 to 9 loop
    --         rx <= frame(i);
    --         wait for UART_BAUD*CLK_PERIOD;
    --     end loop;

    --     frame := '1' & size(23 downto 16) & '0';
    --     for i in 0 to 9 loop
    --         rx <= frame(i);
    --         wait for UART_BAUD*CLK_PERIOD;
    --     end loop;

    --     frame := '1' & size(15 downto  8) & '0';
    --     for i in 0 to 9 loop
    --         rx <= frame(i);
    --         wait for UART_BAUD*CLK_PERIOD;
    --     end loop;

    --     frame := '1' & size(7  downto  0) & '0';
    --     for i in 0 to 9 loop
    --         rx <= frame(i);
    --         wait for UART_BAUD*CLK_PERIOD;
    --     end loop;

    --     for i in 0 to addr loop
    --         frame := '1' & mem(i) & '0';
    --         for j in 0 to 9 loop
    --             rx <= frame(j);
    --             wait for UART_BAUD*CLK_PERIOD;
    --         end loop;
    --         report integer'image(i);
    --     end loop;

    --     rx <= '1';
    --     wait;
    -- end process ld_program;

    -- wr_output: process
    --     variable data : std_logic_vector(7 downto 0);
    --     type charfile is file of character;
    --     file out_file: charfile;
    -- begin
    --     data := x"FF";
    --     file_open(out_file, "STD_OUTPUT", write_mode);
    --     while true loop
    --         wait until tx = '0';
    --         wait for UART_BAUD*CLK_PERIOD;
    --         wait for UART_BAUD*CLK_PERIOD/2;
    --         for i in 0 to 7 loop
    --             data(i) := tx;
    --             wait for UART_BAUD*CLK_PERIOD;
    --         end loop;
    --         write(out_file, character'val(to_integer(unsigned(data))));
    --     end loop;
    --     file_close(out_file);
    --     wait;
    -- end process wr_output;

end package leaf_soc_tb_pkg;

package body leaf_soc_tb_pkg is

    impure function load_mem_data(constant file_path : string) return byte_array is
        type char_file is file of character;
        file mem_file : char_file;
        variable byte : character;
        variable mem_data : byte_array := (others => (others => '0'));
        variable addr : natural := 0;
    begin
        file_open(mem_file, file_path, read_mode);
        while not endfile(mem_file) loop
            if addr < MEM_SIZE then
                read(mem_file, byte);
                mem_data(addr) := std_logic_vector(to_unsigned(character'pos(byte), 8));
                addr := addr + 1;
            else
                report "load_mem_data: program too large for memory" severity error;
                exit;
            end if;
        end loop;
        file_close(mem_file);
        return mem_data;
    end function load_mem_data;

    procedure uart_tx(
        constant baud : time;
        constant data : std_logic_vector(7 downto 0);
        signal tx : out std_logic
    ) is
    begin
        tx <= '0';
        wait for baud;
        for i in 0 to 7 loop
            tx <= data(i);
            wait for baud;
        end loop;
        tx <= '1';
        wait for baud;
    end procedure uart_tx;

    procedure uart_rx(
        constant baud : time;
        signal data : out std_logic_vector(7 downto 0);
        signal rx : in std_logic
    ) is
    begin
        wait until rx = '0';
        wait for baud/2;
        for i in 0 to 7 loop
            wait for baud;
            data(i) <= rx;
        end loop;
        wait for baud;
    end procedure uart_rx;

end package body leaf_soc_tb_pkg;
