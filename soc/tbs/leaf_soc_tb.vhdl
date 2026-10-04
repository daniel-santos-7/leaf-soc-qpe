library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;
use work.leaf_soc_pkg.all;
use work.leaf_soc_tb_pkg.all;
use work.uart_tb_pkg.uart_transmit, work.uart_tb_pkg.uart_receive;

entity leaf_soc_tb is
    generic (
        PROGRAM        : string;
        SKIP_UART_LOAD : boolean := false;
        RUN_CYCLES     : natural := 500000;
        SAMPLES_FILE   : string := "";
        WGEN_IF_COP    : boolean := true;
        DBG_TEST       : boolean := false
    );
end entity leaf_soc_tb;

architecture tb of leaf_soc_tb is

    signal clk    : std_logic;
    signal rst_n  : std_logic;
    signal rx     : std_logic;
    signal tx     : std_logic;
    signal sig_i  : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sig_q  : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal active : std_logic;

    signal uart_data : std_logic_vector(7 downto 0);

    signal sclk_o  : std_logic;
    signal sclk_oe : std_logic;
    signal cs_n_o  : std_logic;
    signal cs_n_oe : std_logic;
    signal mosi_o  : std_logic;
    signal mosi_oe : std_logic;
    signal miso_o  : std_logic;
    signal miso_oe : std_logic;
    signal dbg     : std_logic;

    signal pad_sclk   : std_logic;
    signal pad_cs_n   : std_logic;
    signal pad_mosi   : std_logic;
    signal pad_miso   : std_logic;
    signal flash_cs_n : std_logic;
    signal flash_miso : std_logic;

    signal gpio_i  : std_logic_vector(GPIO_WIDTH-1 downto 0);
    signal gpio_o  : std_logic_vector(GPIO_WIDTH-1 downto 0);
    signal gpio_oe : std_logic_vector(GPIO_WIDTH-1 downto 0);

    signal dbg_sclk : std_logic;
    signal dbg_cs_n : std_logic;
    signal dbg_mosi : std_logic;

    constant DBG_HALF : natural := 5;

    signal dac_sel : std_logic;

    constant DAC_EXT : std_logic_vector(OUT_RES_BITS-1 downto 0) := "0100100011";

    constant GPIO_EXT : std_logic_vector(GPIO_WIDTH-1 downto 0) := "10100101";

    signal clk_en : std_logic := '0';

    constant CLK_PERIOD : time := 10 ns;

    constant RAM_JUMP_CMD : std_logic_vector(7 downto 0) := x"4A";
    constant ACK          : std_logic_vector(7 downto 0) := x"06";

begin

    uut: leaf_soc generic map (
        WGEN_IF_COP => WGEN_IF_COP
    ) port map (
        clk     => clk,
        rst_n   => rst_n,
        rx      => rx,
        tx      => tx,
        sig_i   => sig_i,
        sig_q   => sig_q,
        active  => active,
        sclk_i  => pad_sclk,
        sclk_o  => sclk_o,
        sclk_oe => sclk_oe,
        cs_n_i  => pad_cs_n,
        cs_n_o  => cs_n_o,
        cs_n_oe => cs_n_oe,
        mosi_i  => pad_mosi,
        mosi_o  => mosi_o,
        mosi_oe => mosi_oe,
        miso_i  => pad_miso,
        miso_o  => miso_o,
        miso_oe => miso_oe,
        dbg     => dbg,
        gpio_i  => gpio_i,
        gpio_o  => gpio_o,
        gpio_oe => gpio_oe,
        dac_dat => DAC_EXT,
        dac_sel => dac_sel
    );

    pad_sclk   <= sclk_o  when sclk_oe  = '1' else dbg_sclk;
    pad_cs_n   <= cs_n_o when cs_n_oe = '1' else dbg_cs_n;
    pad_mosi   <= mosi_o when mosi_oe = '1' else dbg_mosi;
    pad_miso   <= miso_o when miso_oe = '1' else flash_miso;
    flash_cs_n <= pad_cs_n when dbg = '0' else '1';

    gpio_pad_proc: process(gpio_o, gpio_oe)
    begin
        for i in gpio_i'range loop
            if gpio_oe(i) = '1' then
                gpio_i(i) <= gpio_o(i);
            else
                gpio_i(i) <= GPIO_EXT(i);
            end if;
        end loop;
    end process gpio_pad_proc;

    u_spi_flash: entity work.spi_flash_model
        generic map (
            INIT_FILE => PROGRAM
        )
        port map (
            spi_sclk => pad_sclk,
            spi_mosi => pad_mosi,
            spi_miso => flash_miso,
            spi_cs_n => flash_cs_n
        );

    clk <= not clk after (CLK_PERIOD/2) when clk_en = '1' else '0';

    uart_rx_proc: process
        type char_file is file of character;
        file out_file : char_file;
        variable rx_data : std_logic_vector(7 downto 0);
        variable char    : character;
    begin
        wait until rst_n = '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        file_open(out_file, "STD_OUTPUT", write_mode);
        rx_loop : loop
            uart_receive(tx, rx_data);
            uart_data <= rx_data;
            char := character'val(to_integer(unsigned(rx_data)));
            write(out_file, char);
        end loop;
        file_close(out_file);
        wait;
    end process uart_rx_proc;

    -- Logs every sig_i/sig_q sample while active='1' to a CSV file for
    -- offline plotting, covering the whole run (all pulses), not just one.
    samples_proc: process
        file f : text;
        variable l     : line;
        variable cycle : natural := 0;
    begin
        if SAMPLES_FILE'length > 0 then
            file_open(f, SAMPLES_FILE, write_mode);
            write(l, string'("cycle,sig_i,sig_q"));
            writeline(f, l);
            loop
                wait until rising_edge(clk) or clk_en = '0';
                exit when clk_en = '0';
                if active = '1' then
                    write(l, cycle);
                    write(l, string'(","));
                    write(l, to_integer(signed(sig_i)));
                    write(l, string'(","));
                    write(l, to_integer(signed(sig_q)));
                    writeline(f, l);
                end if;
                cycle := cycle + 1;
            end loop;
            file_close(f);
        end if;
        wait;
    end process samples_proc;

    test: process
        variable dbg_data : std_logic_vector(31 downto 0);
        variable dbg_stat : std_logic_vector(31 downto 0);

        procedure dbg_wait(constant n : in natural) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure dbg_wait;

        procedure dbg_frame(constant tx_bits : in std_logic_vector; variable rx_bits : out std_logic_vector) is
            variable t : std_logic_vector(tx_bits'length-1 downto 0);
            variable r : std_logic_vector(tx_bits'length-1 downto 0);
        begin
            t := tx_bits;
            dbg_cs_n <= '0';
            dbg_wait(DBG_HALF);
            for i in t'high downto 0 loop
                dbg_mosi <= t(i);
                dbg_wait(DBG_HALF);
                dbg_sclk <= '1';
                r(i) := pad_miso;
                dbg_wait(DBG_HALF);
                dbg_sclk <= '0';
            end loop;
            dbg_wait(DBG_HALF);
            dbg_cs_n <= '1';
            dbg_wait(2*DBG_HALF);
            rx_bits := r;
        end procedure dbg_frame;

        procedure dbg_word(constant w_tx : in std_logic_vector(31 downto 0); variable w_rx : out std_logic_vector(31 downto 0)) is
        begin
            dbg_frame(w_tx, w_rx);
        end procedure dbg_word;

        procedure dbg_cmd(constant w_tx : in std_logic_vector(31 downto 0)) is
            variable r : std_logic_vector(31 downto 0);
        begin
            dbg_frame(w_tx, r);
        end procedure dbg_cmd;

        procedure dbg_write(constant addr : in std_logic_vector(31 downto 0); constant data : in std_logic_vector(31 downto 0)) is
        begin
            dbg_cmd(addr(31 downto 2) & "01");
            dbg_cmd(data);
        end procedure dbg_write;

        procedure dbg_read(constant addr : in std_logic_vector(31 downto 0); variable data : out std_logic_vector(31 downto 0); variable stat : out std_logic_vector(31 downto 0)) is
        begin
            dbg_cmd(addr(31 downto 2) & "00");
            dbg_word(x"00000003", data);
            dbg_word(x"00000003", stat);
        end procedure dbg_read;

        procedure dbg_status(variable stat : out std_logic_vector(31 downto 0)) is
        begin
            dbg_cmd(x"00000003");
            dbg_word(x"00000003", stat);
        end procedure dbg_status;
    begin
        dbg_sclk <= '0';
        dbg_cs_n <= '1';
        dbg_mosi <= '0';
        dbg      <= '0';
        dac_sel  <= '0';
        rst_n    <= '0';
        rx       <= '1';
        clk_en   <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        rst_n <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);

        for i in 0 to 511 loop
            wait until rising_edge(clk);
        end loop;

        if SKIP_UART_LOAD then
            report "RAM preloaded, sending RAM_JUMP_CMD...";
            uart_transmit(rx, RAM_JUMP_CMD);
            wait until uart_data = ACK for 100 us;
            if uart_data = ACK then
                report "ACK received after RAM_JUMP_CMD, program started!";
            else
                report "ERROR: No ACK after RAM_JUMP_CMD" severity failure;
            end if;
        else
            leaf_soc_send_program(rx, uart_data, PROGRAM);
        end if;

        dac_sel <= '1';
        wait until rising_edge(clk);
        assert sig_i = DAC_EXT and sig_q = DAC_EXT report "parallel port not on sig_i/sig_q" severity failure;
        dac_sel <= '0';
        wait until rising_edge(clk);
        assert active = '1' or (sig_i = (sig_i'range => '0') and sig_q = (sig_q'range => '0')) report "pulse generator not back on sig_i/sig_q" severity failure;

        if DBG_TEST then
            dbg <= '1';
            dbg_wait(4);
            dbg_cmd(x"00000007");
            dbg_word(x"00000003", dbg_data);
            assert dbg_data = DBG_ID report "DBG: bad ID" severity failure;

            dbg_write(x"90000000", x"DEADBEEF");
            dbg_read(x"90000000", dbg_data, dbg_stat);
            assert dbg_data = x"DEADBEEF" and dbg_stat = x"00000000" report "DBG: RAM1 read mismatch" severity failure;

            dbg_cmd(x"90000005");
            dbg_frame(x"00", dbg_data(7 downto 0));
            dbg_cmd(x"90000000");
            dbg_word(x"00000003", dbg_data);
            assert dbg_data = x"DEADBEEF" report "DBG: short frame did not cancel the pending write" severity failure;

            dbg_read(x"00001000", dbg_data, dbg_stat);
            assert dbg_data = x"00000000" and dbg_stat = x"00000002" report "DBG: ROM read did not fault" severity failure;

            dbg_cmd(x"00000006");
            dbg_status(dbg_stat);
            assert dbg_stat = x"00000003" report "DBG: bad status after halt" severity failure;

            dbg_read(x"80000000", dbg_data, dbg_stat);
            assert dbg_stat = x"00000001" report "DBG: RAM0 read faulted" severity failure;

            dbg_cmd(x"00000002");
            dbg <= '0';
            dbg_wait(512);
            uart_transmit(rx, RAM_JUMP_CMD);
            wait on uart_data'transaction until uart_data = ACK for 1 ms;
            assert uart_data = ACK report "DBG: no ACK after release" severity failure;
            report "DBG ok: id, RAM1 write/read, short frame, ROM err, halt, release";
        end if;

        for i in 0 to RUN_CYCLES-1 loop
            wait until rising_edge(clk);
        end loop;

        clk_en <= '0';
        wait;
    end process test;

end architecture tb;
