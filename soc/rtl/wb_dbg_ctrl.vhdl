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
        tx_valid_o : out std_logic;
        tx_ready_i : in  std_logic;
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

    type spi_state_t is (S_IDLE, S_EXEC, S_RESP);
    type bus_state_t is (B_IDLE, B_SEND, B_BUSY);

    signal spi_state_reg : spi_state_t;
    signal tx_valid_reg  : std_logic;
    signal ready_reg     : std_logic;
    signal halt_reg      : std_logic;

    signal bus_state_reg : bus_state_t;
    signal cyc_reg       : std_logic;
    signal stb_reg       : std_logic;
    signal we_reg        : std_logic;
    signal adr_reg       : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal dat_reg       : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal err_reg       : std_logic;

    signal resp_reg      : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal cmd_word      : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal op            : std_logic_vector(1 downto 0);
    signal rx_full       : std_logic;
    signal rd_req        : std_logic;
    signal wr_req        : std_logic;
    signal bus_done      : std_logic;
    signal status        : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

begin

    cmd_word <= rx_data_i(SPI_WIDTH-1 downto SOC_DATA_WIDTH);
    op       <= cmd_word(1 downto 0);
    rx_full  <= '1' when unsigned(rx_bits_i) = SPI_WIDTH else '0';

    rd_req   <= '1' when spi_state_reg = S_IDLE and rx_valid_i = '1' and rx_full = '1' and op = OP_READ else '0';
    wr_req   <= '1' when spi_state_reg = S_IDLE and rx_valid_i = '1' and rx_full = '1' and op = OP_WRITE else '0';
    bus_done <= '1' when bus_state_reg = B_BUSY and (ack_i or err_i) = '1' else '0';

    spi_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                spi_state_reg <= S_RESP;
                tx_valid_reg  <= '1';
                ready_reg     <= '1';
                halt_reg      <= '0';
            else
                case spi_state_reg is
                    when S_IDLE =>
                        if rx_valid_i = '1' then
                            if rx_full = '1' then
                                case op is
                                    when OP_READ | OP_WRITE =>
                                        spi_state_reg <= S_EXEC;
                                        tx_valid_reg  <= '1';
                                        ready_reg     <= '0';
                                    when OP_CTRL =>
                                        spi_state_reg <= S_RESP;
                                        tx_valid_reg  <= '1';
                                        halt_reg      <= cmd_word(2);
                                    when OP_INFO =>
                                        spi_state_reg <= S_RESP;
                                        tx_valid_reg  <= '1';
                                    when others =>
                                        null;
                                end case;
                            else
                                spi_state_reg <= S_RESP;
                                tx_valid_reg  <= '1';
                            end if;
                        end if;
                    when S_EXEC =>
                        if bus_done = '1' then
                            spi_state_reg <= S_RESP;
                            ready_reg     <= '1';
                        end if;
                    when S_RESP =>
                        if tx_ready_i = '1' then
                            spi_state_reg <= S_IDLE;
                            tx_valid_reg  <= '0';
                        end if;
                end case;
            end if;
        end if;
    end process spi_proc;

    bus_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                bus_state_reg <= B_IDLE;
                cyc_reg       <= '0';
                stb_reg       <= '0';
                we_reg        <= '0';
                adr_reg       <= (others => '0');
                dat_reg       <= (others => '0');
                err_reg       <= '0';
            else
                case bus_state_reg is
                    when B_IDLE =>
                        if (rd_req or wr_req) = '1' then
                            bus_state_reg <= B_SEND;
                            cyc_reg       <= '1';
                            stb_reg       <= '1';
                            we_reg        <= wr_req;
                            adr_reg       <= cmd_word(SOC_ADDR_WIDTH-1 downto 2);
                            dat_reg       <= rx_data_i(SOC_DATA_WIDTH-1 downto 0);
                        end if;
                    when B_SEND =>
                        if stall_i = '0' then
                            bus_state_reg <= B_BUSY;
                            stb_reg       <= '0';
                        end if;
                    when B_BUSY =>
                        if (ack_i or err_i) = '1' then
                            bus_state_reg <= B_IDLE;
                            cyc_reg       <= '0';
                            we_reg        <= '0';
                            err_reg       <= err_i and not ack_i;
                        end if;
                end case;
            end if;
        end if;
    end process bus_proc;

    resp_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                resp_reg <= (others => '0');
            elsif spi_state_reg = S_IDLE and rx_valid_i = '1' and rx_full = '1' and op = OP_INFO and cmd_word(2) = '1' then
                resp_reg <= DBG_ID;
            elsif bus_state_reg = B_BUSY and we_reg = '0' then
                if ack_i = '1' then
                    resp_reg <= dat_i;
                elsif err_i = '1' then
                    resp_reg <= (others => '0');
                end if;
            end if;
        end if;
    end process resp_proc;

    status <= ready_reg & cyc_reg & err_reg & halt_reg & (SOC_DATA_WIDTH-5 downto 0 => '0');

    tx_valid_o <= tx_valid_reg;
    tx_data_o  <= status & resp_reg;
    cyc_o      <= cyc_reg;
    stb_o      <= stb_reg;
    we_o       <= we_reg;
    sel_o      <= (others => '1');
    adr_o      <= adr_reg;
    dat_o      <= dat_reg;
    halt_o     <= halt_reg;

end architecture rtl;
