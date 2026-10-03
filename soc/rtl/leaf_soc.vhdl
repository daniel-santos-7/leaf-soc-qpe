----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: leaf system (SOC)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_soc_pkg.all;

entity leaf_soc is
    generic (
        WGEN_IF_COP : boolean := true
    );
    port (
        clk      : in  std_logic;
        rst_n    : in  std_logic;
        rx       : in  std_logic;
        tx       : out std_logic;
        sig_i    : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q    : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        active   : out std_logic;
        spi_clk  : out std_logic;
        spi_mosi : out std_logic;
        spi_miso : in  std_logic;
        spi_cs_n : out std_logic;
        gpio_i   : in  std_logic_vector(GPIO_WIDTH-1 downto 0);
        gpio_o   : out std_logic_vector(GPIO_WIDTH-1 downto 0);
        gpio_oe  : out std_logic_vector(GPIO_WIDTH-1 downto 0);
        dac_dat  : in  std_logic_vector(OUT_RES_BITS-1 downto 0);
        dac_sel  : in  std_logic;
        dbg_sck  : in  std_logic;
        dbg_cs_n : in  std_logic;
        dbg_mosi : in  std_logic;
        dbg_miso : out std_logic
    );
end entity leaf_soc;

architecture rtl of leaf_soc is

    signal soc_syscon_clk : std_logic;
    signal soc_syscon_rst : std_logic;
    signal soc_cpu_rst    : std_logic;

    signal soc_cpu_inst_cyc : std_logic;
    signal soc_cpu_inst_stb : std_logic;
    signal soc_cpu_inst_adr : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal soc_cpu_inst_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_cpu_inst_ack : std_logic;
    signal soc_cpu_inst_err : std_logic;

    signal soc_cpu_data_cyc : std_logic;
    signal soc_cpu_data_stb : std_logic;
    signal soc_cpu_data_we  : std_logic;
    signal soc_cpu_data_sel : std_logic_vector(3 downto 0);
    signal soc_cpu_data_adr : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal soc_cpu_data_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_cpu_data_dat_rd : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_cpu_data_ack : std_logic;
    signal soc_cpu_data_err : std_logic;

    signal soc_cpu_inst_stall : std_logic;
    signal soc_cpu_data_stall : std_logic;

    signal soc_inst_rom_cyc : std_logic;
    signal soc_inst_rom_stb : std_logic;
    signal soc_inst_rom_adr : std_logic_vector(ROM_ADDR_WIDTH-1 downto 2);
    signal soc_inst_xip_cyc : std_logic;
    signal soc_inst_xip_stb : std_logic;
    signal soc_inst_xip_adr : std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
    signal soc_ram0_b_cyc : std_logic;
    signal soc_ram0_b_stb : std_logic;
    signal soc_ram0_b_adr : std_logic_vector(RAM0_ADDR_WIDTH-1 downto 2);
    signal soc_ram0_b_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram0_b_ack : std_logic;
    signal soc_ram1_b_cyc : std_logic;
    signal soc_ram1_b_stb : std_logic;
    signal soc_ram1_b_adr : std_logic_vector(RAM1_ADDR_WIDTH-1 downto 2);
    signal soc_ram1_b_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram1_b_ack : std_logic;

    signal soc_data_io0_cyc : std_logic;
    signal soc_data_io0_stb : std_logic;
    signal soc_data_io0_we  : std_logic;
    signal soc_data_io0_sel : std_logic_vector(3 downto 0);
    signal soc_data_io0_adr : std_logic_vector(IO0_ADDR_WIDTH-1 downto 2);
    signal soc_data_io0_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_data_io1_cyc : std_logic;
    signal soc_data_io1_stb : std_logic;
    signal soc_data_io1_we  : std_logic;
    signal soc_data_io1_sel : std_logic_vector(3 downto 0);
    signal soc_data_io1_adr : std_logic_vector(IO1_ADDR_WIDTH-1 downto 2);
    signal soc_data_io1_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_data_io2_cyc : std_logic;
    signal soc_data_io2_stb : std_logic;
    signal soc_data_io2_we  : std_logic;
    signal soc_data_io2_sel : std_logic_vector(3 downto 0);
    signal soc_data_io2_adr : std_logic_vector(IO2_ADDR_WIDTH-1 downto 2);
    signal soc_data_io2_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram0_a_cyc : std_logic;
    signal soc_ram0_a_stb : std_logic;
    signal soc_ram0_a_we  : std_logic;
    signal soc_ram0_a_sel : std_logic_vector(3 downto 0);
    signal soc_ram0_a_adr : std_logic_vector(RAM0_ADDR_WIDTH-1 downto 2);
    signal soc_ram0_a_dat_wr : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram0_a_dat_rd : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram0_a_ack : std_logic;
    signal soc_ram1_a_cyc : std_logic;
    signal soc_ram1_a_stb : std_logic;
    signal soc_ram1_a_we  : std_logic;
    signal soc_ram1_a_sel : std_logic_vector(3 downto 0);
    signal soc_ram1_a_adr : std_logic_vector(RAM1_ADDR_WIDTH-1 downto 2);
    signal soc_ram1_a_dat_wr : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram1_a_dat_rd : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram1_a_ack : std_logic;

    signal soc_rom_ack : std_logic;
    signal soc_rom_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_io0_ack : std_logic;
    signal soc_io0_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_io1_ack : std_logic;
    signal soc_io1_err : std_logic;
    signal soc_io1_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_io2_ack : std_logic;
    signal soc_io2_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_gpio_irq : std_logic;

    signal soc_xip_ack : std_logic;
    signal soc_xip_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_xip_tx_data  : std_logic_vector(7 downto 0);
    signal soc_xip_tx_last  : std_logic;
    signal soc_xip_tx_valid : std_logic;
    signal soc_xip_tx_ready : std_logic;
    signal soc_xip_rx_data  : std_logic_vector(7 downto 0);
    signal soc_xip_rx_valid : std_logic;

    signal soc_dbg_active   : std_logic;
    signal soc_dbg_rx_data  : std_logic_vector(7 downto 0);
    signal soc_dbg_rx_valid : std_logic;
    signal soc_dbg_tx_data  : std_logic_vector(7 downto 0);
    signal soc_dbg_tx_valid : std_logic;
    signal soc_dbg_tx_ready : std_logic;

    signal soc_dbg_cyc   : std_logic;
    signal soc_dbg_stb   : std_logic;
    signal soc_dbg_we    : std_logic;
    signal soc_dbg_sel   : std_logic_vector(3 downto 0);
    signal soc_dbg_adr   : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal soc_dbg_dat_w : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_dbg_dat_r : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_dbg_ack   : std_logic;
    signal soc_dbg_err   : std_logic;
    signal soc_dbg_stall : std_logic;
    signal soc_dbg_halt  : std_logic;

    signal soc_qpe_sig_i : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal soc_qpe_sig_q : std_logic_vector(OUT_RES_BITS-1 downto 0);

    signal soc_cop_csr_rdata : std_logic_vector(31 downto 0);

begin

    soc_syscon: entity work.wb_syscon port map (
        clk   => clk,
        rst_n => rst_n,
        clk_o => soc_syscon_clk,
        rst_o => soc_syscon_rst
    );

    soc_cpu_rst <= soc_syscon_rst or soc_dbg_halt;

    soc_dbg_spi: entity work.spi_slave port map (
        clk_i      => soc_syscon_clk,
        rst_i      => soc_syscon_rst,
        sck_i      => dbg_sck,
        cs_n_i     => dbg_cs_n,
        mosi_i     => dbg_mosi,
        miso_o     => dbg_miso,
        active_o   => soc_dbg_active,
        rx_data_o  => soc_dbg_rx_data,
        rx_valid_o => soc_dbg_rx_valid,
        tx_data_i  => soc_dbg_tx_data,
        tx_valid_i => soc_dbg_tx_valid,
        tx_ready_o => soc_dbg_tx_ready
    );

    soc_dbg_ctrl: entity work.wb_dbg_ctrl port map (
        clk_i      => soc_syscon_clk,
        rst_i      => soc_syscon_rst,
        active_i   => soc_dbg_active,
        rx_data_i  => soc_dbg_rx_data,
        rx_valid_i => soc_dbg_rx_valid,
        tx_data_o  => soc_dbg_tx_data,
        tx_valid_o => soc_dbg_tx_valid,
        tx_ready_i => soc_dbg_tx_ready,
        cyc_o      => soc_dbg_cyc,
        stb_o      => soc_dbg_stb,
        we_o       => soc_dbg_we,
        sel_o      => soc_dbg_sel,
        adr_o      => soc_dbg_adr,
        dat_o      => soc_dbg_dat_w,
        dat_i      => soc_dbg_dat_r,
        ack_i      => soc_dbg_ack,
        err_i      => soc_dbg_err,
        stall_i    => soc_dbg_stall,
        halt_o     => soc_dbg_halt
    );

    sig_i <= dac_dat when dac_sel = '1' else soc_qpe_sig_i;
    sig_q <= dac_dat when dac_sel = '1' else soc_qpe_sig_q;

    cop_qpe_gen: if WGEN_IF_COP generate
        soc_cpu: entity work.leaf_qpe generic map (
            RESET_ADDR => ROM_BASE_ADDR
        ) port map (
            clk_i    => soc_syscon_clk,
            rst_i    => soc_cpu_rst,
            ex_irq_i => soc_gpio_irq,
            sw_irq_i => '0',
            tm_irq_i => '0',
            inst_cyc_o   => soc_cpu_inst_cyc,
            inst_stb_o   => soc_cpu_inst_stb,
            inst_adr_o   => soc_cpu_inst_adr,
            inst_dat_i   => soc_cpu_inst_dat,
            inst_ack_i   => soc_cpu_inst_ack,
            inst_err_i   => soc_cpu_inst_err,
            inst_stall_i => soc_cpu_inst_stall,
            data_cyc_o   => soc_cpu_data_cyc,
            data_stb_o   => soc_cpu_data_stb,
            data_we_o    => soc_cpu_data_we,
            data_sel_o   => soc_cpu_data_sel,
            data_adr_o   => soc_cpu_data_adr,
            data_dat_o   => soc_cpu_data_dat,
            data_dat_i   => soc_cpu_data_dat_rd,
            data_ack_i   => soc_cpu_data_ack,
            data_err_i   => soc_cpu_data_err,
            data_stall_i => soc_cpu_data_stall,
            sig_i_o  => soc_qpe_sig_i,
            sig_q_o  => soc_qpe_sig_q,
            active_o => active
        );

        soc_io1_ack <= '0';
        soc_io1_err <= '1';
        soc_io1_dat <= (others => '0');
    end generate;

    mmio_qpe_gen: if not WGEN_IF_COP generate
        soc_cpu: entity work.leaf generic map (
            RESET_ADDR => ROM_BASE_ADDR
        ) port map (
            clk_i        => soc_syscon_clk,
            rst_i        => soc_cpu_rst,
            ex_irq_i     => soc_gpio_irq,
            sw_irq_i     => '0',
            tm_irq_i     => '0',
            cop_dat_i    => soc_cop_csr_rdata,
            cop_adr_o    => open,
            cop_dat_o    => open,
            cop_we_o     => open,
            rf_wr_en_o    => open,
            rf_wr_addr_o  => open,
            rf_wr_data_o  => open,
            inst_cyc_o   => soc_cpu_inst_cyc,
            inst_stb_o   => soc_cpu_inst_stb,
            inst_adr_o   => soc_cpu_inst_adr,
            inst_dat_i   => soc_cpu_inst_dat,
            inst_ack_i   => soc_cpu_inst_ack,
            inst_err_i   => soc_cpu_inst_err,
            inst_stall_i => soc_cpu_inst_stall,
            data_cyc_o   => soc_cpu_data_cyc,
            data_stb_o   => soc_cpu_data_stb,
            data_we_o    => soc_cpu_data_we,
            data_sel_o   => soc_cpu_data_sel,
            data_adr_o   => soc_cpu_data_adr,
            data_dat_o   => soc_cpu_data_dat,
            data_dat_i   => soc_cpu_data_dat_rd,
            data_ack_i   => soc_cpu_data_ack,
            data_err_i   => soc_cpu_data_err,
            data_stall_i => soc_cpu_data_stall
        );

        soc_cop_csr_rdata <= (others => '0');
        soc_io1_err <= '0';

        soc_wb_sig_gen: entity work.wb_sig_gen port map (
            rst_i    => soc_syscon_rst,
            clk_i    => soc_syscon_clk,
            adr_i    => soc_data_io1_adr,
            cyc_i    => soc_data_io1_cyc,
            stb_i    => soc_data_io1_stb,
            we_i     => soc_data_io1_we,
            sel_i    => soc_data_io1_sel,
            dat_i    => soc_data_io1_dat,
            ack_o    => soc_io1_ack,
            stall_o  => open,
            dat_o    => soc_io1_dat,
            sig_i_o  => soc_qpe_sig_i,
            sig_q_o  => soc_qpe_sig_q,
            active_o => active
        );
    end generate;

    soc_intercon: entity work.wb_intercon port map (
        clk_i        => soc_syscon_clk,
        rst_i        => soc_syscon_rst,
        inst_cyc_i   => soc_cpu_inst_cyc,
        inst_stb_i   => soc_cpu_inst_stb,
        inst_adr_i   => soc_cpu_inst_adr,
        inst_dat_o   => soc_cpu_inst_dat,
        inst_ack_o   => soc_cpu_inst_ack,
        inst_err_o   => soc_cpu_inst_err,
        inst_stall_o => soc_cpu_inst_stall,
        data_cyc_i   => soc_cpu_data_cyc,
        data_stb_i   => soc_cpu_data_stb,
        data_we_i    => soc_cpu_data_we,
        data_sel_i   => soc_cpu_data_sel,
        data_adr_i   => soc_cpu_data_adr,
        data_dat_i   => soc_cpu_data_dat,
        data_dat_o   => soc_cpu_data_dat_rd,
        data_ack_o   => soc_cpu_data_ack,
        data_err_o   => soc_cpu_data_err,
        data_stall_o => soc_cpu_data_stall,
        dbg_cyc_i    => soc_dbg_cyc,
        dbg_stb_i    => soc_dbg_stb,
        dbg_we_i     => soc_dbg_we,
        dbg_sel_i    => soc_dbg_sel,
        dbg_adr_i    => soc_dbg_adr,
        dbg_dat_i    => soc_dbg_dat_w,
        dbg_dat_o    => soc_dbg_dat_r,
        dbg_ack_o    => soc_dbg_ack,
        dbg_err_o    => soc_dbg_err,
        dbg_stall_o  => soc_dbg_stall,
        rom_cyc_o    => soc_inst_rom_cyc,
        rom_stb_o    => soc_inst_rom_stb,
        rom_adr_o    => soc_inst_rom_adr,
        rom_ack_i    => soc_rom_ack,
        rom_dat_i    => soc_rom_dat,
        xip_cyc_o    => soc_inst_xip_cyc,
        xip_stb_o    => soc_inst_xip_stb,
        xip_adr_o    => soc_inst_xip_adr,
        xip_ack_i    => soc_xip_ack,
        xip_dat_i    => soc_xip_dat,
        ram0b_cyc_o  => soc_ram0_b_cyc,
        ram0b_stb_o  => soc_ram0_b_stb,
        ram0b_adr_o  => soc_ram0_b_adr,
        ram0b_ack_i  => soc_ram0_b_ack,
        ram0b_dat_i  => soc_ram0_b_dat,
        ram1b_cyc_o  => soc_ram1_b_cyc,
        ram1b_stb_o  => soc_ram1_b_stb,
        ram1b_adr_o  => soc_ram1_b_adr,
        ram1b_ack_i  => soc_ram1_b_ack,
        ram1b_dat_i  => soc_ram1_b_dat,
        io0_cyc_o    => soc_data_io0_cyc,
        io0_stb_o    => soc_data_io0_stb,
        io0_we_o     => soc_data_io0_we,
        io0_sel_o    => soc_data_io0_sel,
        io0_adr_o    => soc_data_io0_adr,
        io0_dat_o    => soc_data_io0_dat,
        io0_ack_i    => soc_io0_ack,
        io0_dat_i    => soc_io0_dat,
        io1_cyc_o    => soc_data_io1_cyc,
        io1_stb_o    => soc_data_io1_stb,
        io1_we_o     => soc_data_io1_we,
        io1_sel_o    => soc_data_io1_sel,
        io1_adr_o    => soc_data_io1_adr,
        io1_dat_o    => soc_data_io1_dat,
        io1_ack_i    => soc_io1_ack,
        io1_err_i    => soc_io1_err,
        io1_dat_i    => soc_io1_dat,
        io2_cyc_o    => soc_data_io2_cyc,
        io2_stb_o    => soc_data_io2_stb,
        io2_we_o     => soc_data_io2_we,
        io2_sel_o    => soc_data_io2_sel,
        io2_adr_o    => soc_data_io2_adr,
        io2_dat_o    => soc_data_io2_dat,
        io2_ack_i    => soc_io2_ack,
        io2_dat_i    => soc_io2_dat,
        ram0a_cyc_o  => soc_ram0_a_cyc,
        ram0a_stb_o  => soc_ram0_a_stb,
        ram0a_we_o   => soc_ram0_a_we,
        ram0a_sel_o  => soc_ram0_a_sel,
        ram0a_adr_o  => soc_ram0_a_adr,
        ram0a_dat_o  => soc_ram0_a_dat_wr,
        ram0a_ack_i  => soc_ram0_a_ack,
        ram0a_dat_i  => soc_ram0_a_dat_rd,
        ram1a_cyc_o  => soc_ram1_a_cyc,
        ram1a_stb_o  => soc_ram1_a_stb,
        ram1a_we_o   => soc_ram1_a_we,
        ram1a_sel_o  => soc_ram1_a_sel,
        ram1a_adr_o  => soc_ram1_a_adr,
        ram1a_dat_o  => soc_ram1_a_dat_wr,
        ram1a_ack_i  => soc_ram1_a_ack,
        ram1a_dat_i  => soc_ram1_a_dat_rd
    );

    soc_rom: entity work.wb_rom port map (
        clk_i => soc_syscon_clk,
        rst_i => soc_syscon_rst,
        cyc_i => soc_inst_rom_cyc,
        stb_i => soc_inst_rom_stb,
        adr_i => soc_inst_rom_adr,
        ack_o => soc_rom_ack,
        dat_o => soc_rom_dat
    );

    soc_uart: entity work.uart_wbsl port map (
        clk_i   => soc_syscon_clk,
        rst_i   => soc_syscon_rst,
        dat_i   => soc_data_io0_dat,
        cyc_i   => soc_data_io0_cyc,
        stb_i   => soc_data_io0_stb,
        we_i    => soc_data_io0_we,
        sel_i   => soc_data_io0_sel,
        adr_i   => soc_data_io0_adr,
        rx_i    => rx,
        ack_o   => soc_io0_ack,
        stall_o => open,
        dat_o   => soc_io0_dat,
        tx_o    => tx
    );

    soc_gpio: entity work.wb_gpio generic map (
        G_WIDTH => GPIO_WIDTH
    ) port map (
        wb_clk_i   => soc_syscon_clk,
        wb_rst_i   => soc_syscon_rst,
        wb_cyc_i   => soc_data_io2_cyc,
        wb_stb_i   => soc_data_io2_stb,
        wb_we_i    => soc_data_io2_we,
        wb_adr_i   => soc_data_io2_adr,
        wb_sel_i   => soc_data_io2_sel,
        wb_dat_i   => soc_data_io2_dat,
        wb_dat_o   => soc_io2_dat,
        wb_ack_o   => soc_io2_ack,
        wb_stall_o => open,
        irq_o      => soc_gpio_irq,
        gpio_i     => gpio_i,
        gpio_o     => gpio_o,
        gpio_oe_o  => gpio_oe
    );

    soc_xip: entity work.wb_xip_ctrl port map (
        clk_i      => soc_syscon_clk,
        rst_i      => soc_syscon_rst,
        cyc_i      => soc_inst_xip_cyc,
        stb_i      => soc_inst_xip_stb,
        adr_i      => soc_inst_xip_adr,
        ack_o      => soc_xip_ack,
        dat_o      => soc_xip_dat,
        tx_data_o  => soc_xip_tx_data,
        tx_last_o  => soc_xip_tx_last,
        tx_valid_o => soc_xip_tx_valid,
        tx_ready_i => soc_xip_tx_ready,
        rx_data_i  => soc_xip_rx_data,
        rx_valid_i => soc_xip_rx_valid
    );

    soc_xip_spi: entity work.spi_master generic map (
        SCK_DIV        => XIP_SCK_DIV,
        CS_HIGH_CYCLES => XIP_CS_HIGH_CYCLES
    ) port map (
        clk_i      => soc_syscon_clk,
        rst_i      => soc_syscon_rst,
        sck_o      => spi_clk,
        cs_n_o     => spi_cs_n,
        mosi_o     => spi_mosi,
        miso_i     => spi_miso,
        tx_data_i  => soc_xip_tx_data,
        tx_last_i  => soc_xip_tx_last,
        tx_valid_i => soc_xip_tx_valid,
        tx_ready_o => soc_xip_tx_ready,
        rx_data_o  => soc_xip_rx_data,
        rx_valid_o => soc_xip_rx_valid
    );

    soc_ram0: wb_ram_dp generic map (
        BITS  => RAM0_ADDR_WIDTH
    ) port map (
        clk_i   => soc_syscon_clk,
        rst_i   => soc_syscon_rst,
        dat_a_i => soc_ram0_a_dat_wr,
        cyc_a_i => soc_ram0_a_cyc,
        stb_a_i => soc_ram0_a_stb,
        we_a_i  => soc_ram0_a_we,
        sel_a_i => soc_ram0_a_sel,
        adr_a_i => soc_ram0_a_adr,
        ack_a_o => soc_ram0_a_ack,
        dat_a_o => soc_ram0_a_dat_rd,
        cyc_b_i => soc_ram0_b_cyc,
        stb_b_i => soc_ram0_b_stb,
        adr_b_i => soc_ram0_b_adr,
        ack_b_o => soc_ram0_b_ack,
        dat_b_o => soc_ram0_b_dat
    );

    soc_ram1: wb_ram_dp generic map (
        BITS  => RAM1_ADDR_WIDTH
    ) port map (
        clk_i   => soc_syscon_clk,
        rst_i   => soc_syscon_rst,
        dat_a_i => soc_ram1_a_dat_wr,
        cyc_a_i => soc_ram1_a_cyc,
        stb_a_i => soc_ram1_a_stb,
        we_a_i  => soc_ram1_a_we,
        sel_a_i => soc_ram1_a_sel,
        adr_a_i => soc_ram1_a_adr,
        ack_a_o => soc_ram1_a_ack,
        dat_a_o => soc_ram1_a_dat_rd,
        cyc_b_i => soc_ram1_b_cyc,
        stb_b_i => soc_ram1_b_stb,
        adr_b_i => soc_ram1_b_adr,
        ack_b_o => soc_ram1_b_ack,
        dat_b_o => soc_ram1_b_dat
    );

end architecture rtl;
