----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: debug controller (Wishbone MASTER)
-- 2026
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.leaf_soc_pkg.all;

entity wb_dbg_ctrl is
    port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        rx_data_i  : in  std_logic_vector(SPI_WIDTH-1 downto 0);
        rx_bits_i  : in  std_logic_vector(SPI_CNT_BITS-1 downto 0);
        rx_valid_i : in  std_logic;
        tx_data_o  : out std_logic_vector(SPI_WIDTH-1 downto 0);
        cyc_o      : out std_logic;
        stb_o      : out std_logic;
        we_o       : out std_logic;
        sel_o      : out std_logic_vector(3 downto 0);
        adr_o      : out std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
        dat_o      : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        dat_i      : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        ack_i      : in  std_logic;
        err_i      : in  std_logic;
        stall_i    : in  std_logic;
        halt_o     : out std_logic
    );
end entity wb_dbg_ctrl;

architecture rtl of wb_dbg_ctrl is

    constant OP_READ  : std_logic_vector(1 downto 0) := "00";
    constant OP_WRITE : std_logic_vector(1 downto 0) := "01";
    constant OP_CTRL  : std_logic_vector(1 downto 0) := "10";
    constant OP_INFO  : std_logic_vector(1 downto 0) := "11";

    signal cmd_word  : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal frame     : std_logic;
    signal op        : std_logic_vector(1 downto 0);
    signal req       : std_logic;

    signal cyc_reg   : std_logic;
    signal stb_reg   : std_logic;
    signal we_reg    : std_logic;
    signal adr_reg   : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal dat_reg   : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal halt_reg  : std_logic;
    signal err_reg   : std_logic;
    signal ovr_reg   : std_logic;
    signal status    : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal resp_reg  : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

begin

    cmd_word <= rx_data_i(SPI_WIDTH-1 downto SOC_DATA_WIDTH);
    frame    <= '1' when rx_valid_i = '1' and unsigned(rx_bits_i) = SPI_WIDTH else '0';
    op       <= cmd_word(1 downto 0);
    req      <= '1' when frame = '1' and (op = OP_READ or op = OP_WRITE) else '0';

    bus_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                cyc_reg <= '0';
                stb_reg <= '0';
                we_reg  <= '0';
                adr_reg <= (others => '0');
                dat_reg <= (others => '0');
                err_reg <= '0';
            elsif cyc_reg = '0' then
                if req = '1' then
                    cyc_reg <= '1';
                    stb_reg <= '1';
                    adr_reg <= cmd_word(SOC_ADDR_WIDTH-1 downto 2);
                    dat_reg <= rx_data_i(SOC_DATA_WIDTH-1 downto 0);
                    if op = OP_WRITE then
                        we_reg <= '1';
                    else
                        we_reg <= '0';
                    end if;
                end if;
            else
                if stb_reg = '1' then
                    if stall_i = '0' then
                        stb_reg <= '0';
                    end if;
                elsif (ack_i or err_i) = '1' then
                    cyc_reg <= '0';
                    we_reg  <= '0';
                    err_reg <= err_i and not ack_i;
                end if;
            end if;
        end if;
    end process bus_proc;

    halt_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                halt_reg <= '0';
            elsif frame = '1' and op = OP_CTRL then
                halt_reg <= cmd_word(2);
            end if;
        end if;
    end process halt_proc;

    ovr_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ovr_reg <= '0';
            elsif req = '1' and cyc_reg = '1' then
                ovr_reg <= '1';
            elsif rx_valid_i = '1' then
                ovr_reg <= '0';
            end if;
        end if;
    end process ovr_proc;

    status <= (SOC_DATA_WIDTH-1 downto 4 => '0') & ovr_reg & cyc_reg & err_reg & halt_reg;

    resp_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                resp_reg <= (others => '0');
            elsif frame = '1' and op = OP_INFO and cmd_word(2) = '1' then
                resp_reg <= DBG_ID;
            elsif cyc_reg = '1' and stb_reg = '0' and we_reg = '0' then
                if ack_i = '1' then
                    resp_reg <= dat_i;
                elsif err_i = '1' then
                    resp_reg <= (others => '0');
                end if;
            end if;
        end if;
    end process resp_proc;

    tx_data_o <= resp_reg & status;
    cyc_o     <= cyc_reg;
    stb_o     <= stb_reg;
    we_o      <= we_reg;
    sel_o     <= (others => '1');
    adr_o     <= adr_reg;
    dat_o     <= dat_reg;
    halt_o    <= halt_reg;

end architecture rtl;
