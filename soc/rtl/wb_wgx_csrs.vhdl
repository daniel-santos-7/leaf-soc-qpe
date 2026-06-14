library IEEE;
use IEEE.std_logic_1164.all;
use work.sine_lut_pkg.OUT_RES_BITS;

entity wb_wgx_csrs is
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        cyc_i : in  std_logic;
        stb_i : in  std_logic;
        we_i  : in  std_logic;
        sel_i : in  std_logic_vector(3 downto 0);
        adr_i : in  std_logic_vector(3 downto 2);
        dat_i : in  std_logic_vector(31 downto 0);
        ack_o : out std_logic;
        dat_o : out std_logic_vector(31 downto 0);
        inc_o : out std_logic_vector(31 downto 0);
        pha_o : out std_logic_vector(31 downto 0);
        amp_o : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        we_o  : out std_logic
    );
end entity wb_wgx_csrs;

architecture rtl of wb_wgx_csrs is

    signal req     : std_logic;
    signal ack_reg : std_logic;
    signal csr_addr : std_logic_vector(5 downto 0);
    signal csr_we   : std_logic;

begin

    req <= cyc_i and stb_i;

    csr_addr <= "0000" & adr_i;
    csr_we <= req and we_i;

    u_wgx: entity work.wgx_csrs port map (
        clk_i   => clk_i,
        rst_i   => rst_i,
        addr_i  => csr_addr,
        wdata_i => dat_i,
        we_i    => csr_we,
        rdata_o => dat_o,
        inc_o   => inc_o,
        pha_o   => pha_o,
        amp_o   => amp_o,
        we_o    => we_o
    );

    ack_reg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ack_reg <= '0';
            elsif ack_reg = '1' then
                ack_reg <= '0';
            else
                ack_reg <= req;
            end if;
        end if;
    end process ack_reg_proc;

    ack_o <= ack_reg;

end architecture rtl;
