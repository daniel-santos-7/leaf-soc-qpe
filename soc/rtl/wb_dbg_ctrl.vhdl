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
        rx_data_i  : in  std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
        rx_bits_i  : in  std_logic_vector(DBG_CNT_BITS-1 downto 0);
        rx_valid_i : in  std_logic;
        tx_data_o  : out std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
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

    type bus_state_t is (B_IDLE, B_REQ, B_WAIT);

    signal bus_state : bus_state_t;
    signal word      : std_logic;
    signal cmd       : std_logic;
    signal op        : std_logic_vector(1 downto 0);
    signal start_wr  : std_logic;
    signal start_rd  : std_logic;
    signal status_rd : std_logic;
    signal id_rd     : std_logic;
    signal busy      : std_logic;
    signal status    : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal wr_pend   : std_logic;
    signal addr_reg  : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal wdata_reg : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal resp_reg  : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal we_reg    : std_logic;
    signal halt_reg  : std_logic;
    signal err_reg   : std_logic;
    signal ovr_reg   : std_logic;

begin

    word      <= '1' when rx_valid_i = '1' and unsigned(rx_bits_i) = SOC_DATA_WIDTH else '0';
    cmd       <= word and not wr_pend;
    op        <= rx_data_i(1 downto 0);
    start_wr  <= word and wr_pend;
    start_rd  <= '1' when cmd = '1' and op = OP_READ else '0';
    status_rd <= '1' when cmd = '1' and op = OP_INFO and rx_data_i(2) = '0' else '0';
    id_rd     <= '1' when cmd = '1' and op = OP_INFO and rx_data_i(2) = '1' else '0';
    busy      <= '0' when bus_state = B_IDLE else '1';
    status    <= (SOC_DATA_WIDTH-1 downto 4 => '0') & ovr_reg & busy & err_reg & halt_reg;

    frame_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                wr_pend   <= '0';
                addr_reg  <= (others => '0');
                wdata_reg <= (others => '0');
                halt_reg  <= '0';
            elsif rx_valid_i = '1' then
                wr_pend <= '0';
                if start_wr = '1' then
                    wdata_reg <= rx_data_i;
                elsif cmd = '1' then
                    case op is
                        when OP_READ =>
                            addr_reg <= rx_data_i(SOC_ADDR_WIDTH-1 downto 2);
                        when OP_WRITE =>
                            addr_reg <= rx_data_i(SOC_ADDR_WIDTH-1 downto 2);
                            wr_pend  <= '1';
                        when OP_CTRL =>
                            halt_reg <= rx_data_i(2);
                        when others =>
                            null;
                    end case;
                end if;
            end if;
        end if;
    end process frame_proc;

    bus_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                bus_state <= B_IDLE;
                we_reg    <= '0';
                err_reg   <= '0';
            else
                case bus_state is
                    when B_IDLE =>
                        if (start_wr or start_rd) = '1' then
                            bus_state <= B_REQ;
                            we_reg    <= start_wr;
                        end if;
                    when B_REQ =>
                        if stall_i = '0' then
                            bus_state <= B_WAIT;
                        end if;
                    when B_WAIT =>
                        if (ack_i or err_i) = '1' then
                            bus_state <= B_IDLE;
                            err_reg   <= err_i and not ack_i;
                        end if;
                end case;
            end if;
        end if;
    end process bus_proc;

    ovr_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                ovr_reg <= '0';
            elsif (start_wr or start_rd) = '1' and bus_state /= B_IDLE then
                ovr_reg <= '1';
            elsif status_rd = '1' then
                ovr_reg <= '0';
            end if;
        end if;
    end process ovr_proc;

    resp_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                resp_reg <= (others => '0');
            elsif status_rd = '1' then
                resp_reg <= status;
            elsif id_rd = '1' then
                resp_reg <= DBG_ID;
            elsif bus_state = B_WAIT and ack_i = '1' and we_reg = '0' then
                resp_reg <= dat_i;
            elsif bus_state = B_WAIT and err_i = '1' and we_reg = '0' then
                resp_reg <= (others => '0');
            end if;
        end if;
    end process resp_proc;

    tx_data_o <= resp_reg;
    cyc_o     <= busy;
    stb_o     <= '1' when bus_state = B_REQ else '0';
    we_o      <= we_reg;
    sel_o     <= (others => '1');
    adr_o     <= addr_reg;
    dat_o     <= wdata_reg;
    halt_o    <= halt_reg;

end architecture rtl;
