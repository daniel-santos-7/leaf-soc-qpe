library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_pkg.all;
use work.leaf_soc_pkg.all;
use work.sig_gen_pkg.all;

entity leaf_wgx is
    generic (
        RESET_ADDR : std_logic_vector(XLEN-1 downto 0) := (others => '0')
    );
    port (
        clk_i     : in  std_logic;
        rst_i     : in  std_logic;
        ex_irq_i  : in  std_logic;
        sw_irq_i  : in  std_logic;
        tm_irq_i  : in  std_logic;
        ack_i     : in  std_logic;
        err_i     : in  std_logic;
        dat_i     : in  std_logic_vector(XLEN-1 downto 0);
        cyc_o     : out std_logic;
        stb_o     : out std_logic;
        we_o      : out std_logic;
        sel_o     : out std_logic_vector(3         downto 0);
        adr_o     : out std_logic_vector(XLEN-1 downto 0);
        dat_o     : out std_logic_vector(XLEN-1 downto 0);
        sig_o     : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o   : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        active_o  : out std_logic
    );
end entity leaf_wgx;

architecture rtl of leaf_wgx is

    signal csr_rdata : std_logic_vector(XLEN-1 downto 0);
    signal csr_addr  : std_logic_vector(5 downto 0);
    signal csr_wdata : std_logic_vector(XLEN-1 downto 0);
    signal csr_we    : std_logic;

    signal wgen_ftw   : std_logic_vector(31 downto 0);
    signal wgen_pow   : std_logic_vector(31 downto 0);
    signal wgen_amp   : std_logic_vector(15 downto 0);
    signal wgen_env   : std_logic_vector(31 downto 0);
    signal wgen_drag  : std_logic_vector(15 downto 0);
    signal wgen_valid : std_logic;
    signal wgen_delay : std_logic_vector(23 downto 0);
    signal wgen_ready : std_logic;

    signal wgen_sig_i : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal wgen_active : std_logic;

begin

    u_cpu: leaf generic map (
        RESET_ADDR => RESET_ADDR
    ) port map (
        clk_i     => clk_i,
        rst_i     => rst_i,
        ex_irq_i  => ex_irq_i,
        sw_irq_i  => sw_irq_i,
        tm_irq_i  => tm_irq_i,
        ack_i     => ack_i,
        err_i     => err_i,
        dat_i     => dat_i,
        cop_dat_i => csr_rdata,
        cop_adr_o => csr_addr,
        cop_dat_o => csr_wdata,
        cop_we_o  => csr_we,
        cyc_o     => cyc_o,
        stb_o     => stb_o,
        we_o      => we_o,
        sel_o     => sel_o,
        adr_o     => adr_o,
        dat_o     => dat_o
    );

    u_csrs: wgx_csrs port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        addr_i  => csr_addr,
        wdata_i => csr_wdata,
        we_i    => csr_we,
        rdata_o => csr_rdata,
        ftw_o   => wgen_ftw,
        pow_o   => wgen_pow,
        amp_o   => wgen_amp,
        env_o   => wgen_env,
        drag_o  => wgen_drag,
        valid_o => wgen_valid,
        delay_o => wgen_delay,
        ready_i => wgen_ready
    );

        u_wgen: sig_gen port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        ftw_i   => wgen_ftw,
        pow_i   => wgen_pow,
        amp_i   => wgen_amp,
        env_i   => wgen_env,
        drag_i  => wgen_drag,
        valid_i => wgen_valid,
        delay_i => wgen_delay,
        ready_o => wgen_ready,
        sig_i_o => wgen_sig_i,
        sig_q_o => sig_q_o,
        active_o => active_o
    );

    sig_o <= wgen_sig_i;

end architecture rtl;
