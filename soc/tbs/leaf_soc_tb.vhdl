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
        DBG_TEST       : boolean := false;
        ROLE_TEST      : boolean := false;
        BOOT_RAM0      : boolean := false;
        TRAP_TEST      : boolean := false;
        COLL_TEST      : boolean := false;
        RAM0_EN        : boolean := true;
        RAM1_EN        : boolean := true
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
    signal dac_chk : std_logic := '0';
    signal dac_clk : std_logic;

    signal uart_data : std_logic_vector(7 downto 0);

    signal sclk_o  : std_logic;
    signal sclk_oe : std_logic;
    signal cs_n_o  : std_logic;
    signal cs_n_oe : std_logic;
    signal mosi_o  : std_logic;
    signal mosi_oe : std_logic;
    signal miso_o  : std_logic;
    signal miso_oe : std_logic;

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
    constant DBG_NOP  : std_logic_vector(31 downto 0) := x"00000003";


    constant DAC_EXT : std_logic_vector(OUT_RES_BITS-1 downto 0) := "0100100011";

    constant GPIO_EXT : std_logic_vector(GPIO_WIDTH-1 downto 0) := "10100101";

    signal clk_en : std_logic := '0';

    constant CLK_PERIOD : time := 10 ns;

    constant RAM_JUMP_CMD  : std_logic_vector(7 downto 0) := x"4A";
    constant RAM_LOAD_CMD  : std_logic_vector(7 downto 0) := x"4C";
    constant RAM0_JUMP_CMD : std_logic_vector(7 downto 0) := x"6A";
    constant RAM0_LOAD_CMD : std_logic_vector(7 downto 0) := x"6C";
    constant ACK           : std_logic_vector(7 downto 0) := x"06";
    constant TRAP_LINE     : string := "! 00000001 10000000 10000000" & LF;

begin

    uut: leaf_soc generic map (
        WGEN_IF_COP => WGEN_IF_COP,
        RAM0_EN     => RAM0_EN,
        RAM1_EN     => RAM1_EN
    ) port map (
        clk     => clk,
        rst_n   => rst_n,
        rx      => rx,
        tx      => tx,
        sig_i   => sig_i,
        sig_q   => sig_q,
        active  => active,
        dac_clk => dac_clk,
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
        gpio_i  => gpio_i,
        gpio_o  => gpio_o,
        gpio_oe => gpio_oe,
        dac_dat => DAC_EXT
    );

    pad_sclk   <= sclk_o  when sclk_oe  = '1' else dbg_sclk;
    pad_cs_n   <= cs_n_o when cs_n_oe = '1' else dbg_cs_n;
    pad_mosi   <= mosi_o when mosi_oe = '1' else dbg_mosi;
    pad_miso   <= miso_o when miso_oe = '1' else '0' when flash_miso = 'Z' else flash_miso;
    flash_cs_n <= pad_cs_n when cs_n_oe = '1' else '1';

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
                wait until rising_edge(dac_clk) or clk_en = '0';
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

    dac_clk_proc: process(dac_clk)
    begin
        if rising_edge(dac_clk) and clk_en = '1' then
            assert sig_i'stable(CLK_PERIOD/2 - 1 ns) and sig_q'stable(CLK_PERIOD/2 - 1 ns) and active'stable(CLK_PERIOD/2 - 1 ns)
                report "sig_i/sig_q/active changed less than half a period before the dac_clk capture edge" severity failure;
            assert dac_chk = '0' or active /= '0' or (sig_i = DAC_EXT and sig_q = DAC_EXT)
                report "dac_dat not on sig_i/sig_q while the pulse generator is idle" severity failure;
        end if;
    end process dac_clk_proc;

    test: process
        variable dbg_data : std_logic_vector(31 downto 0);
        variable dbg_stat : std_logic_vector(31 downto 0);
        variable coll_cnt0 : std_logic_vector(31 downto 0);
        variable coll_word : std_logic_vector(31 downto 0);
        variable dbg_junk : std_logic_vector(31 downto 0);
        variable dbg_early : std_logic_vector(63 downto 0);

        procedure dbg_wait(constant n : in natural) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk);
            end loop;
        end procedure dbg_wait;

        procedure dbg_frame(constant tx_bits : in std_logic_vector; variable rx_bits : out std_logic_vector; constant gap : in natural := 2*DBG_HALF) is
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
            dbg_wait(gap);
            rx_bits := r;
        end procedure dbg_frame;

        procedure dbg_xfer(constant cmd : in std_logic_vector(31 downto 0); constant data : in std_logic_vector(31 downto 0);
                           variable res : out std_logic_vector(31 downto 0); variable stat : out std_logic_vector(31 downto 0)) is
            variable r : std_logic_vector(63 downto 0);
        begin
            dbg_frame(cmd & data, r);
            stat := r(63 downto 32);
            res  := r(31 downto 0);
        end procedure dbg_xfer;

        procedure dbg_cmd(constant cmd : in std_logic_vector(31 downto 0); constant data : in std_logic_vector(31 downto 0)) is
            variable r : std_logic_vector(63 downto 0);
        begin
            dbg_frame(cmd & data, r);
        end procedure dbg_cmd;

        procedure dbg_write(constant addr : in std_logic_vector(31 downto 0); constant data : in std_logic_vector(31 downto 0)) is
        begin
            dbg_cmd(addr(31 downto 2) & "01", data);
        end procedure dbg_write;

        procedure dbg_read(constant addr : in std_logic_vector(31 downto 0); variable data : out std_logic_vector(31 downto 0); variable stat : out std_logic_vector(31 downto 0)) is
        begin
            dbg_cmd(addr(31 downto 2) & "00", x"00000000");
            dbg_xfer(DBG_NOP, x"00000000", data, stat);
        end procedure dbg_read;

        procedure dbg_empty(constant gap : in natural := 2*DBG_HALF) is
        begin
            dbg_cs_n <= '0';
            dbg_wait(2*DBG_HALF);
            dbg_cs_n <= '1';
            dbg_wait(gap);
        end procedure dbg_empty;
    begin
        dbg_sclk <= '0';
        dbg_cs_n <= '1';
        dbg_mosi <= '0';
        rst_n    <= '0';
        rx       <= '1';
        clk_en   <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait for 1 ns;
        assert active = '0' and sig_i = (sig_i'range => '0') and sig_q = (sig_q'range => '0')
            report "sig_i/sig_q/active not 0 during reset" severity failure;

        rst_n <= '1';
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        dac_chk <= '1';

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
        elsif BOOT_RAM0 then
            leaf_soc_send_program(rx, uart_data, PROGRAM, RAM0_LOAD_CMD, RAM0_JUMP_CMD);
        else
            leaf_soc_send_program(rx, uart_data, PROGRAM, RAM_LOAD_CMD, RAM_JUMP_CMD);
        end if;

        if DBG_TEST then
            dbg_wait(4);
            dbg_cmd(x"0000000A", x"00000000");
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_data = DBG_ID report "DBG: bad ID" severity failure;

            dbg_write(x"80000000", x"DEADBEEF");
            dbg_read(x"80000000", dbg_data, dbg_stat);
            assert dbg_data = x"DEADBEEF" and dbg_stat = x"C0000000" report "DBG: RAM0 read mismatch" severity failure;

            dbg_frame(x"80000001", dbg_junk);
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_data = x"DEADBEEF" and dbg_stat = x"A0000000" report "DBG: short frame did not report ERR" severity failure;

            dbg_empty;
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_data = x"DEADBEEF" and dbg_stat = x"A0000000" report "DBG: empty frame was not ignored" severity failure;

            dbg_write(x"80000000", x"DEADBEEF");
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_data = x"00000000" and dbg_stat = x"C0000000" report "DBG: WRITE did not clear the result" severity failure;

            dbg_cmd(x"0000000E", x"00000000");
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_data = x"00000000" and dbg_stat = x"A0000000" report "DBG: reserved CTRL subcommand did not report ERR" severity failure;

            dbg_empty(2);
            dbg_frame(x"80000009" & x"CAFEF00D", dbg_early);
            dbg_read(x"80000008", dbg_data, dbg_stat);
            assert dbg_early(63) = '1' and dbg_data = x"CAFEF00D" report "DBG: command right after an empty frame was dropped" severity failure;

            dbg_frame(x"80000005" & x"12345678", dbg_early, 2);
            dbg_frame(x"80000004" & x"00000000", dbg_early);
            assert dbg_early = x"00000000" & x"00000000" report "DBG: early frame did not get the busy reply" severity failure;
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_data = x"00000000" and dbg_stat = x"C0000000" report "DBG: early frame was not dropped" severity failure;

            dbg_frame(x"8000000D" & x"11111111", dbg_early, 1);
            dbg_frame(x"8000000C" & x"00000000", dbg_early);
            assert dbg_early(63) = '0' report "DBG: READY set in a frame 1 cycle after a command" severity failure;
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_data = x"00000000" and dbg_stat = x"C0000000" report "DBG: command followed by a frame 1 cycle later did not run or the frame was not dropped" severity failure;

            dbg_read(x"00001000", dbg_data, dbg_stat);
            assert dbg_data = x"00000000" and dbg_stat = x"A0000000" report "DBG: ROM read did not fault" severity failure;

            dbg_cmd(x"00000006", x"00000000");
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_stat = x"D0000000" report "DBG: bad status after halt" severity failure;

            dbg_read(x"90000000", dbg_data, dbg_stat);
            assert dbg_stat = x"D0000000" report "DBG: RAM1 read faulted" severity failure;

            dbg_cmd(x"00000002", x"00000000");
            dbg_wait(512);
            uart_transmit(rx, RAM_JUMP_CMD);
            wait on uart_data'transaction until uart_data = ACK for 1 ms;
            assert uart_data = ACK report "DBG: no ACK after release" severity failure;

            dbg_cmd(x"00000006", x"00000000");
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_stat = x"D0000000" report "DBG: bad status after the second halt" severity failure;
            dbg_write(x"20FFFFFC", x"00000001");
            dbg_wait(512);
            uart_transmit(rx, RAM_JUMP_CMD);
            wait on uart_data'transaction until uart_data = ACK for 1 ms;
            assert uart_data = ACK report "DBG: setting EN did not release the halted CPU" severity failure;
            report "DBG ok: id, RAM0 write/read, short and empty frames, reserved CTRL, frame right after an empty one, early frame, ROM err, halt, release, EN releases halt";
        end if;

        if ROLE_TEST then
            wait on uart_data'transaction until uart_data = x"77" for 2 ms;
            assert uart_data = x"77" report "ROLE: program did not start" severity failure;
            dbg_wait(4);
            dbg_cmd(x"0000000A", x"00000000");
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_data = DBG_ID report "ROLE: bad ID" severity failure;

            dbg_write(x"80000010", x"600DF00D");
            wait on uart_data'transaction until uart_data = x"52" for 2 ms;
            assert uart_data = x"52" report "ROLE: program did not come back from XIP" severity failure;

            dbg_xfer(x"80000014", x"00000000", dbg_data, dbg_stat);
            assert dbg_data = x"00000000" and dbg_stat = x"C0000000" report "ROLE: first frame after XIP did not get the last debug reply" severity failure;
            dbg_xfer(DBG_NOP, x"00000000", dbg_data, dbg_stat);
            assert dbg_data = x"0EFFF9DC" and dbg_stat = x"C0000000" report "ROLE: command in the first frame after XIP did not run" severity failure;

            wait on uart_data'transaction until uart_data = x"0A" for 4 ms;
            assert uart_data = x"0A" report "ROLE: program did not finish its ROLE line" severity failure;
            dbg_write(x"80000018", x"5EC0DD00");
            dbg_cs_n <= '0';
            dbg_wait(20000);
            dbg_cs_n <= '1';
            wait on uart_data'transaction until uart_data = x"57" for 2 ms;
            assert uart_data = x"57" report "ROLE: program did not finish the EN_WAIT check" severity failure;
            dbg_wait(4);
            dbg_read(x"8000001C", dbg_data, dbg_stat);
            assert dbg_data = x"00000001" report "ROLE: a fetch before the master role took effect did not answer ERR" severity failure;
            dbg_read(x"80000020", dbg_data, dbg_stat);
            assert dbg_data = x"00" & std_logic_vector(to_unsigned(XIP_SCK_DIV - 1, 8)) & std_logic_vector(to_unsigned(XIP_CS_HIGH_CYCLES, 8)) & x"01"
                report "ROLE: ACT was set while the host held its frame" severity failure;
            dbg_read(x"80000024", dbg_data, dbg_stat);
            assert dbg_data = x"0EFFF9DC" report "ROLE: XIP did not work once the master role took effect" severity failure;
            report "ROLE ok: debug -> XIP -> debug, last reply kept, first command after XIP runs, fetch in EN_WAIT answers ERR";
        end if;

        if COLL_TEST then
            dbg_wait(4);
            dbg_read(x"90000008", coll_word, dbg_stat);
            for i in 1 to 300 loop
                dbg_write(x"90000008", coll_word);
            end loop;
            dbg_read(x"90000008", dbg_data, dbg_stat);
            assert dbg_data = coll_word report "COLL: the rewritten instruction changed" severity failure;
            dbg_read(x"80000000", coll_cnt0, dbg_stat);
            dbg_wait(200);
            dbg_read(x"80000000", dbg_data, dbg_stat);
            assert unsigned(dbg_data) > unsigned(coll_cnt0) report "COLL: the CPU stopped while its loop was rewritten" severity failure;
            report "COLL ok: 300 writes over the loop being fetched, loop intact, CPU still counting";
        end if;

        if TRAP_TEST then
            for k in 1 to 2 loop
                for i in TRAP_LINE'range loop
                    wait on uart_data'transaction for 1 ms;
                    assert uart_data = std_logic_vector(to_unsigned(character'pos(TRAP_LINE(i)), 8))
                        report "TRAP: wrong trap report from the boot ROM" severity failure;
                end loop;
                if k = 1 then
                    uart_transmit(rx, RAM_JUMP_CMD);
                    wait on uart_data'transaction until uart_data = ACK for 1 ms;
                    assert uart_data = ACK report "TRAP: boot ROM did not take a command after the trap" severity failure;
                end if;
            end loop;
            report "TRAP ok: trap reported with mcause, mepc and mtval, boot ROM back in its command loop";
        end if;

        for i in 0 to RUN_CYCLES-1 loop
            wait until rising_edge(clk);
        end loop;

        clk_en <= '0';
        wait;
    end process test;

end architecture tb;
