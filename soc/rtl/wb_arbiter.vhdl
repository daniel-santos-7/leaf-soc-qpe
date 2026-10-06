----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: Wishbone arbiter (two MASTERS, one channel)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use work.leaf_soc_pkg.all;

entity wb_arbiter is
    port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        m0_cyc_i   : in  std_logic;
        m0_stb_i   : in  std_logic;
        m0_we_i    : in  std_logic;
        m0_sel_i   : in  std_logic_vector(3 downto 0);
        m0_adr_i   : in  std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
        m0_dat_i   : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        m0_dat_o   : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        m0_ack_o   : out std_logic;
        m0_err_o   : out std_logic;
        m0_stall_o : out std_logic;
        m1_cyc_i   : in  std_logic;
        m1_stb_i   : in  std_logic;
        m1_we_i    : in  std_logic;
        m1_sel_i   : in  std_logic_vector(3 downto 0);
        m1_adr_i   : in  std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
        m1_dat_i   : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        m1_dat_o   : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        m1_ack_o   : out std_logic;
        m1_err_o   : out std_logic;
        m1_stall_o : out std_logic;
        s_cyc_o    : out std_logic;
        s_stb_o    : out std_logic;
        s_we_o     : out std_logic;
        s_sel_o    : out std_logic_vector(3 downto 0);
        s_adr_o    : out std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
        s_dat_o    : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        s_dat_i    : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        s_ack_i    : in  std_logic;
        s_err_i    : in  std_logic;
        s_stall_i  : in  std_logic
    );
end entity wb_arbiter;

architecture rtl of wb_arbiter is

    signal gnt     : std_logic;
    signal gnt_reg : std_logic;
    signal m0_hold : std_logic;
    signal m1_hold : std_logic;

begin

    m0_hold <= m0_cyc_i and not gnt_reg;
    m1_hold <= m1_cyc_i and gnt_reg;
    gnt     <= m1_hold or (m1_cyc_i and not m0_hold);

    gnt_reg_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                gnt_reg <= '0';
            else
                gnt_reg <= gnt;
            end if;
        end if;
    end process gnt_reg_proc;

    s_cyc_o <= m1_cyc_i when gnt = '1' else m0_cyc_i;
    s_stb_o <= m1_stb_i when gnt = '1' else m0_stb_i;
    s_we_o  <= m1_we_i  when gnt = '1' else m0_we_i;
    s_sel_o <= m1_sel_i when gnt = '1' else m0_sel_i;
    s_adr_o <= m1_adr_i when gnt = '1' else m0_adr_i;
    s_dat_o <= m1_dat_i when gnt = '1' else m0_dat_i;

    m0_dat_o   <= s_dat_i;
    m0_ack_o   <= s_ack_i and not gnt;
    m0_err_o   <= s_err_i and not gnt;
    m0_stall_o <= s_stall_i or gnt;

    m1_dat_o   <= s_dat_i;
    m1_ack_o   <= s_ack_i and gnt;
    m1_err_o   <= s_err_i and gnt;
    m1_stall_o <= s_stall_i or not gnt;

end architecture rtl;
