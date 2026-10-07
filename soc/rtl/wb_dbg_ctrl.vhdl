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
    signal start_wr  : std_logic;
    signal start_rd  : std_logic;
    signal ctrl_wr   : std_logic;
    signal id_rd     : std_logic;
    signal start     : std_logic;

    signal cyc_reg   : std_logic;
    signal stb_reg   : std_logic;
    signal we_reg    : std_logic;
    signal adr_reg   : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal dat_reg   : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal done      : std_logic;

    signal halt_reg  : std_logic;
    signal err_reg   : std_logic;
    signal ovr_reg   : std_logic;
    signal status    : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal resp_reg  : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

begin

    cmd_word <= rx_data_i(SPI_WIDTH-1 downto SOC_DATA_WIDTH);
    frame    <= '1' when rx_valid_i = '1' and unsigned(rx_bits_i) = SPI_WIDTH else '0';
    op       <= cmd_word(1 downto 0);
    start_wr <= '1' when frame = '1' and op = OP_WRITE else '0';
    start_rd <= '1' when frame = '1' and op = OP_READ else '0';
    ctrl_wr  <= '1' when frame = '1' and op = OP_CTRL else '0';
    id_rd    <= '1' when frame = '1' and op = OP_INFO and cmd_word(2) = '1' else '0';

    start <= (start_wr or start_rd) and not cyc_reg;
    done  <= cyc_reg and not stb_reg and (ack_i or err_i);

    cyc_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                cyc_reg <= '0';
            elsif start = '1' then
                cyc_reg <= '1';
            elsif done = '1' then
                cyc_reg <= '0';
            end if;
        end if;
    end process cyc_proc;

    stb_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                stb_reg <= '0';
            elsif start = '1' then
                stb_reg <= '1';
            elsif stall_i = '0' then
                stb_reg <= '0';
            end if;
        end if;
    end process stb_proc;

    we_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                we_reg <= '0';
            elsif start = '1' then
                we_reg <= start_wr;
            elsif done = '1' then
                we_reg <= '0';
            end if;
        end if;
    end process we_proc;

    adr_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                adr_reg <= (others => '0');
            elsif start = '1' then
                adr_reg <= cmd_word(SOC_ADDR_WIDTH-1 downto 2);
            end if;
        end if;
    end process adr_proc;

    dat_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                dat_reg <= (others => '0');
            elsif start = '1' then
                dat_reg <= rx_data_i(SOC_DATA_WIDTH-1 downto 0);
            end if;
        end if;
    end process dat_proc;

    halt_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                halt_reg <= '0';
            elsif ctrl_wr = '1' then
                halt_reg <= cmd_word(2);
            end if;
        end if;
    end process halt_proc;

    err_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                err_reg <= '0';
            elsif done = '1' then
                err_reg <= err_i and not ack_i;
            end if;
        end if;
    end process err_proc;

    ovr_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ovr_reg <= '0';
            elsif (start_wr or start_rd) = '1' and cyc_reg = '1' then
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
            elsif id_rd = '1' then
                resp_reg <= DBG_ID;
            elsif done = '1' and ack_i = '1' and we_reg = '0' then
                resp_reg <= dat_i;
            elsif done = '1' and we_reg = '0' then
                resp_reg <= (others => '0');
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
