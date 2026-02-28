library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package uart_tb_pkg is

    constant CLK_PERIOD : time := 20 ns;

    constant UART_9600_BAUD_RATE_PERIOD : time := 104160 ns;

    constant UART_115200_BAUD_RATE_PERIOD : time := 8680 ns;

    constant UART_9600_BAUD_RATE_DIVIDER : unsigned(31 downto 0) := to_unsigned(UART_9600_BAUD_RATE_PERIOD/CLK_PERIOD, 32);

    constant UART_115200_BAUD_RATE_DIVIDER : unsigned(31 downto 0) := to_unsigned(UART_115200_BAUD_RATE_PERIOD/CLK_PERIOD, 32);

    procedure uart_transmit(
        signal tx : out std_logic;
        constant data : in std_logic_vector(7 downto 0);
        constant baud : in time := UART_115200_BAUD_RATE_PERIOD
    );

    procedure uart_receive(
        signal rx : in std_logic;
        variable data : out std_logic_vector(7 downto 0);
        constant baud : in time := UART_115200_BAUD_RATE_PERIOD
    );

    procedure uart_expect (
        signal rx : in std_logic;
        constant data : in std_logic_vector(7 downto 0);
        constant baud : in time := UART_115200_BAUD_RATE_PERIOD
    );

    type wishbone_bus_t is record
        cyc_o : std_logic;
        stb_o : std_logic;
        we_o  : std_logic;
        sel_o : std_logic_vector(3 downto 0);
        adr_o : std_logic_vector(1 downto 0);
        dat_o : std_logic_vector(31 downto 0);
        ack_i : std_logic;
        dat_i : std_logic_vector(31 downto 0);
    end record wishbone_bus_t;

    procedure wb_init (
        signal wb_bus : out wishbone_bus_t
    );

    procedure wb_write (
        constant addr : in std_logic_vector;
        constant data : in std_logic_vector;
        signal clk    : in std_logic;
        signal wb_bus : inout wishbone_bus_t
    );

    procedure wb_read (
        constant addr : in  std_logic_vector;
        variable data : out std_logic_vector;
        signal clk    : in  std_logic;
        signal wb_bus : inout wishbone_bus_t
    );

    procedure wb_check (
        constant addr : in  std_logic_vector;
        constant data : in  std_logic_vector;
        signal clk    : in  std_logic;
        signal wb_bus : inout wishbone_bus_t
    );

end package;

package body uart_tb_pkg is

    procedure uart_transmit (
        signal tx : out std_logic;
        constant data : in std_logic_vector(7 downto 0);
        constant baud : in time := UART_115200_BAUD_RATE_PERIOD
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
    end procedure uart_transmit;

    procedure uart_receive (
        signal rx : in std_logic;
        variable data : out std_logic_vector(7 downto 0);
        constant baud : in time := UART_115200_BAUD_RATE_PERIOD
    ) is
    begin
        wait until rx = '0';
        wait for baud/2;
        for i in 0 to 7 loop
            wait for baud;
            data(i) := rx;
        end loop;
        wait for baud;
    end procedure uart_receive;

    procedure uart_expect (
        signal rx     : in std_logic;
        constant data : in std_logic_vector(7 downto 0);
        constant baud : in time := UART_115200_BAUD_RATE_PERIOD
    ) is
        variable received_data : std_logic_vector(7 downto 0);
        variable result : boolean;
    begin
        uart_receive(rx, received_data, baud);
        result := data = received_data;
        if result then
            report "uart_check PASSED: got " & integer'image(to_integer(unsigned(received_data)))
                severity note;
        end if;
        assert result
            report "uart_check FAILED: expected " & integer'image(to_integer(unsigned(data))) &
                   ", got " & integer'image(to_integer(unsigned(received_data)))
            severity error;
    end procedure uart_expect;

    procedure wb_init (
        signal wb_bus : out wishbone_bus_t
    ) is
    begin
        wb_bus.cyc_o <= '0';
        wb_bus.stb_o <= '0';
        wb_bus.we_o  <= '0';
        wb_bus.sel_o <= (others => '1');
        wb_bus.adr_o <= (others => '0');
        wb_bus.dat_o <= (others => '0');
        wb_bus.dat_i <= (others => 'Z');
        wb_bus.ack_i <= 'Z';
    end procedure wb_init;

    procedure wb_write (
        constant addr : in std_logic_vector;
        constant data : in std_logic_vector;
        signal clk    : in std_logic;
        signal wb_bus : inout wishbone_bus_t
    ) is
    begin
        wait until rising_edge(clk);
        wb_bus.cyc_o <= '1';
        wb_bus.stb_o <= '1';
        wb_bus.we_o  <= '1';
        wb_bus.adr_o <= addr;
        wb_bus.dat_o <= data;

        loop
            wait until rising_edge(clk);
            if wb_bus.ack_i = '1' then
                exit;
            end if;
        end loop;

        wb_bus.cyc_o <= '0';
        wb_bus.stb_o <= '0';
        wb_bus.we_o  <= '0';
    end procedure wb_write;

    procedure wb_read (
        constant addr : in  std_logic_vector;
        variable data : out std_logic_vector;
        signal clk    : in  std_logic;
        signal wb_bus : inout wishbone_bus_t
    ) is
    begin
        wait until rising_edge(clk);
        wb_bus.cyc_o <= '1';
        wb_bus.stb_o <= '1';
        wb_bus.we_o  <= '0';
        wb_bus.adr_o <= addr;
        wb_bus.dat_o <= (others => '0');

        loop
            wait until rising_edge(clk);
            if wb_bus.ack_i = '1' then
                data := wb_bus.dat_i;
                exit;
            end if;
        end loop;

        wb_bus.cyc_o <= '0';
        wb_bus.stb_o <= '0';
        wb_bus.we_o  <= '0';
    end procedure wb_read;

    procedure wb_check (
        constant addr : in  std_logic_vector;
        constant data : in  std_logic_vector;
        signal clk    : in  std_logic;
        signal wb_bus : inout wishbone_bus_t
    ) is
        variable received_data : std_logic_vector(data'range);
        variable result : boolean;
    begin
        wb_read(addr, received_data, clk, wb_bus);
        result := data = received_data;
        if result then
            report "wb_check PASSED at address " & integer'image(to_integer(unsigned(addr))) &
                    ": got " & integer'image(to_integer(unsigned(data)))
            severity note;
        end if;
        assert result
            report "wb_check FAILED at address " & integer'image(to_integer(unsigned(addr))) &
                    ": expected " & integer'image(to_integer(unsigned(data))) &
                    ", got "      & integer'image(to_integer(unsigned(received_data)))
            severity error;
    end procedure wb_check;

end package body;
