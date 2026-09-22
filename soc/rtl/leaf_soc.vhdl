library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_pkg.all;
use work.leaf_soc_pkg.all;
use work.uart_pkg.all;
use work.wgen_cfg.all;

entity leaf_soc is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        rx       : in  std_logic;
        tx       : out std_logic;
        sig_i    : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q    : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        active   : out std_logic;
        spi_clk  : out std_logic;
        spi_mosi : out std_logic;
        spi_miso : in  std_logic;
        spi_cs_n : out std_logic
    );
end entity leaf_soc;

architecture rtl of leaf_soc is

    signal soc_syscon_clk : std_logic;
    signal soc_syscon_rst : std_logic;

    -- CPU instruction channel
    signal soc_cpu_inst_cyc : std_logic;
    signal soc_cpu_inst_stb : std_logic;
    signal soc_cpu_inst_adr : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal soc_cpu_inst_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_cpu_inst_ack : std_logic;
    signal soc_cpu_inst_err : std_logic;

    -- CPU data channel
    signal soc_cpu_data_cyc : std_logic;
    signal soc_cpu_data_stb : std_logic;
    signal soc_cpu_data_we  : std_logic;
    signal soc_cpu_data_sel : std_logic_vector(3 downto 0);
    signal soc_cpu_data_adr : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal soc_cpu_data_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_cpu_data_dat_rd : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_cpu_data_ack : std_logic;
    signal soc_cpu_data_err : std_logic;

    -- Stall signals (backpressure: cyc without ack)
    signal soc_cpu_inst_stall : std_logic;
    signal soc_cpu_data_stall : std_logic;

    -- intercon_inst (I-channel): ROM, XIP, wb_ram_dp port B (read-only)
    signal soc_inst_rom_cyc : std_logic;
    signal soc_inst_rom_stb : std_logic;
    signal soc_inst_rom_adr : std_logic_vector(ROM_ADDR_WIDTH-1 downto 2);
    signal soc_inst_xip_cyc : std_logic;
    signal soc_inst_xip_stb : std_logic;
    signal soc_inst_xip_we  : std_logic;
    signal soc_inst_xip_sel : std_logic_vector(3 downto 0);
    signal soc_inst_xip_adr : std_logic_vector(XIP_ADDR_WIDTH-1 downto 2);
    signal soc_inst_xip_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram_b_cyc : std_logic;
    signal soc_ram_b_stb : std_logic;
    signal soc_ram_b_adr : std_logic_vector(RAM_ADDR_WIDTH-1 downto 2);
    signal soc_ram_b_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram_b_ack : std_logic;

    -- intercon_data (D-channel): UART, IO1, wb_ram_dp port A (read-write)
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
    signal soc_ram_a_cyc : std_logic;
    signal soc_ram_a_stb : std_logic;
    signal soc_ram_a_we  : std_logic;
    signal soc_ram_a_sel : std_logic_vector(3 downto 0);
    signal soc_ram_a_adr : std_logic_vector(RAM_ADDR_WIDTH-1 downto 2);
    signal soc_ram_a_dat_wr : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram_a_dat_rd : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal soc_ram_a_ack : std_logic;

    signal soc_rom_ack : std_logic;
    signal soc_rom_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_io0_ack : std_logic;
    signal soc_io0_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_io1_ack : std_logic;
    signal soc_io1_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_xip_ack : std_logic;
    signal soc_xip_err : std_logic;
    signal soc_xip_dat : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal soc_cop_csr_rdata : std_logic_vector(31 downto 0);

begin

    soc_syscon: wb_syscon port map (
        clk   => clk,
        rst   => rst,
        clk_o => soc_syscon_clk,
        rst_o => soc_syscon_rst
    );

    cop_wgx_gen: if WGEN_IF_COP generate
        soc_cpu: leaf_wgx generic map (
            RESET_ADDR => ROM_BASE_ADDR
        ) port map (
            clk_i    => soc_syscon_clk,
            rst_i    => soc_syscon_rst,
            ex_irq_i => '0',
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
            sig_i_o  => sig_i,
            sig_q_o  => sig_q,
            active_o => active
        );

        soc_io1_ack <= '0';
        soc_io1_dat <= (others => '0');
    end generate;

    mmio_wgx_gen: if not WGEN_IF_COP generate
        soc_cpu: leaf generic map (
            RESET_ADDR => ROM_BASE_ADDR
        ) port map (
            clk_i        => soc_syscon_clk,
            rst_i        => soc_syscon_rst,
            ex_irq_i     => '0',
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
            -- Pipelined-mode port: the CSR file never inserts wait states
            -- (stall_o is tied low) and wb_intercon has no stall path.
            stall_o  => open,
            dat_o    => soc_io1_dat,
            sig_i_o  => sig_i,
            sig_q_o  => sig_q,
            active_o => active
        );
    end generate;

    soc_cpu_inst_stall <= '0';
    soc_cpu_data_stall <= '0';

    -- Instruction channel interconnect: ROM, XIP, wb_ram_dp port B
    intercon_inst: wb_intercon port map (
        clk_i     => soc_syscon_clk,
        rst_i     => soc_syscon_rst,
        cpu_cyc_i => soc_cpu_inst_cyc,
        cpu_stb_i => soc_cpu_inst_stb,
        cpu_we_i  => '0',
        cpu_sel_i => (others => '1'),
        cpu_adr_i => soc_cpu_inst_adr,
        cpu_dat_i => (others => '0'),
        rom_ack_i => soc_rom_ack,
        io0_ack_i => '0',
        io1_ack_i => '0',
        xip_ack_i => soc_xip_ack,
        ram_ack_i => soc_ram_b_ack,
        xip_err_i => soc_xip_err,
        rom_dat_i => soc_rom_dat,
        io0_dat_i => (others => '0'),
        io1_dat_i => (others => '0'),
        xip_dat_i => soc_xip_dat,
        ram_dat_i => soc_ram_b_dat,
        cpu_ack_o => soc_cpu_inst_ack,
        cpu_err_o => soc_cpu_inst_err,
        rom_cyc_o => soc_inst_rom_cyc,
        io0_cyc_o => open,
        io1_cyc_o => open,
        xip_cyc_o => soc_inst_xip_cyc,
        ram_cyc_o => soc_ram_b_cyc,
        rom_stb_o => soc_inst_rom_stb,
        io0_stb_o => open,
        io1_stb_o => open,
        xip_stb_o => soc_inst_xip_stb,
        ram_stb_o => soc_ram_b_stb,
        io0_we_o  => open,
        io1_we_o  => open,
        xip_we_o  => soc_inst_xip_we,
        ram_we_o  => open,
        io0_sel_o => open,
        io1_sel_o => open,
        xip_sel_o => soc_inst_xip_sel,
        ram_sel_o => open,
        rom_adr_o => soc_inst_rom_adr,
        io0_adr_o => open,
        io1_adr_o => open,
        xip_adr_o => soc_inst_xip_adr,
        ram_adr_o => soc_ram_b_adr,
        cpu_dat_o => soc_cpu_inst_dat,
        io0_dat_o => open,
        io1_dat_o => open,
        xip_dat_o => soc_inst_xip_dat,
        ram_dat_o => open
    );

    -- Data channel interconnect: UART, IO1, wb_ram_dp port A
    intercon_data: wb_intercon port map (
        clk_i     => soc_syscon_clk,
        rst_i     => soc_syscon_rst,
        cpu_cyc_i => soc_cpu_data_cyc,
        cpu_stb_i => soc_cpu_data_stb,
        cpu_we_i  => soc_cpu_data_we,
        cpu_sel_i => soc_cpu_data_sel,
        cpu_adr_i => soc_cpu_data_adr,
        cpu_dat_i => soc_cpu_data_dat,
        rom_ack_i => '0',
        io0_ack_i => soc_io0_ack,
        io1_ack_i => soc_io1_ack,
        xip_ack_i => '0',
        ram_ack_i => soc_ram_a_ack,
        xip_err_i => '0',
        rom_dat_i => (others => '0'),
        io0_dat_i => soc_io0_dat,
        io1_dat_i => soc_io1_dat,
        xip_dat_i => (others => '0'),
        ram_dat_i => soc_ram_a_dat_rd,
        cpu_ack_o => soc_cpu_data_ack,
        cpu_err_o => soc_cpu_data_err,
        rom_cyc_o => open,
        io0_cyc_o => soc_data_io0_cyc,
        io1_cyc_o => soc_data_io1_cyc,
        xip_cyc_o => open,
        ram_cyc_o => soc_ram_a_cyc,
        rom_stb_o => open,
        io0_stb_o => soc_data_io0_stb,
        io1_stb_o => soc_data_io1_stb,
        xip_stb_o => open,
        ram_stb_o => soc_ram_a_stb,
        io0_we_o  => soc_data_io0_we,
        io1_we_o  => soc_data_io1_we,
        xip_we_o  => open,
        ram_we_o  => soc_ram_a_we,
        io0_sel_o => soc_data_io0_sel,
        io1_sel_o => soc_data_io1_sel,
        xip_sel_o => open,
        ram_sel_o => soc_ram_a_sel,
        rom_adr_o => open,
        io0_adr_o => soc_data_io0_adr,
        io1_adr_o => soc_data_io1_adr,
        xip_adr_o => open,
        ram_adr_o => soc_ram_a_adr,
        cpu_dat_o => soc_cpu_data_dat_rd,
        io0_dat_o => soc_data_io0_dat,
        io1_dat_o => soc_data_io1_dat,
        xip_dat_o => open,
        ram_dat_o => soc_ram_a_dat_wr
    );

    soc_rom: wb_rom port map (
        clk_i => soc_syscon_clk,
        rst_i => soc_syscon_rst,
        cyc_i => soc_inst_rom_cyc,
        stb_i => soc_inst_rom_stb,
        adr_i => soc_inst_rom_adr,
        ack_o => soc_rom_ack,
        dat_o => soc_rom_dat
    );

    soc_uart: uart_wbsl port map (
        clk_i => soc_syscon_clk,
        rst_i => soc_syscon_rst,
        dat_i => soc_data_io0_dat,
        cyc_i => soc_data_io0_cyc,
        stb_i => soc_data_io0_stb,
        we_i  => soc_data_io0_we,
        sel_i => soc_data_io0_sel,
        adr_i => soc_data_io0_adr,
        rx    => rx,
        ack_o => soc_io0_ack,
        dat_o => soc_io0_dat,
        tx    => tx
    );

    -- XIP controller
    soc_xip: wb_xip_ctrl port map (
        clk_i     => soc_syscon_clk,
        rst_i     => soc_syscon_rst,
        cyc_i     => soc_inst_xip_cyc,
        stb_i     => soc_inst_xip_stb,
        we_i      => soc_inst_xip_we,
        sel_i     => soc_inst_xip_sel,
        adr_i     => soc_inst_xip_adr,
        dat_i     => soc_inst_xip_dat,
        ack_o     => soc_xip_ack,
        err_o     => soc_xip_err,
        dat_o     => soc_xip_dat,
        spi_clk   => spi_clk,
        spi_mosi  => spi_mosi,
        spi_miso  => spi_miso,
        spi_cs_n  => spi_cs_n
    );

    -- memory 32 kB (dual-port: A = data R/W, B = instruction R/O)
    soc_ram: wb_ram_dp generic map (
        BITS  => RAM_ADDR_WIDTH
    ) port map (
        clk_i   => soc_syscon_clk,
        rst_i   => soc_syscon_rst,
        dat_i   => soc_ram_a_dat_wr,
        cyc_i   => soc_ram_a_cyc,
        stb_i   => soc_ram_a_stb,
        we_i    => soc_ram_a_we,
        sel_i   => soc_ram_a_sel,
        adr_i   => soc_ram_a_adr,
        ack_o   => soc_ram_a_ack,
        dat_o   => soc_ram_a_dat_rd,
        cyc_b_i => soc_ram_b_cyc,
        stb_b_i => soc_ram_b_stb,
        adr_b_i => soc_ram_b_adr,
        ack_b_o => soc_ram_b_ack,
        dat_b_o => soc_ram_b_dat
    );

end architecture rtl;
