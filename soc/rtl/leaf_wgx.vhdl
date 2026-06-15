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
        sig_o     : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity leaf_wgx;

architecture rtl of leaf_wgx is

    signal csr_rdata : std_logic_vector(XLEN-1 downto 0);
    signal csr_addr  : std_logic_vector(5 downto 0);
    signal csr_wdata : std_logic_vector(XLEN-1 downto 0);
    signal csr_we    : std_logic;

    signal wgen_inc  : std_logic_vector(31 downto 0);
    signal wgen_pha  : std_logic_vector(31 downto 0);
    signal wgen_amp  : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal wgen_we   : std_logic;

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
        inc_o   => wgen_inc,
        pha_o   => wgen_pha,
        amp_o   => wgen_amp,
        we_o    => wgen_we
    );

    u_wgen: sig_gen port map (
        clk_i => clk_i,
        rst_i => rst_i,
        we_i  => wgen_we,
        inc_i => wgen_inc,
        pha_i => wgen_pha,
        amp_i => wgen_amp,
        sig_o => sig_o
    );

end architecture rtl;
