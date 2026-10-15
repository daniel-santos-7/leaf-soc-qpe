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
    constant OP_NOP   : std_logic_vector(1 downto 0) := "11";

    constant SUB_RUN  : std_logic_vector(1 downto 0) := "00";
    constant SUB_HALT : std_logic_vector(1 downto 0) := "01";
    constant SUB_ID   : std_logic_vector(1 downto 0) := "10";

    type spi_state_t is (S_IDLE, S_EXEC, S_CTRL);
    type bus_state_t is (B_IDLE, B_SEND, B_BUSY);

    signal spi_state_reg : spi_state_t;
    signal ready_reg     : std_logic;
    signal halt_reg      : std_logic;
    signal resp_reg      : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

    signal bus_state_reg : bus_state_t;
    signal cyc_reg       : std_logic;
    signal stb_reg       : std_logic;
    signal we_reg        : std_logic;
    signal adr_reg       : std_logic_vector(SOC_ADDR_WIDTH-1 downto 2);
    signal dat_reg       : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal ack_reg       : std_logic;
    signal err_reg       : std_logic;


    signal cmd_word      : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal op            : std_logic_vector(1 downto 0);
    signal sub           : std_logic_vector(1 downto 0);
    signal rx_full       : std_logic;
    signal rd_req        : std_logic;
    signal wr_req        : std_logic;
    signal bus_done      : std_logic;
    signal status        : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);

begin

    cmd_word <= rx_data_i(SPI_WIDTH-1 downto SOC_DATA_WIDTH);
    op       <= cmd_word(1 downto 0);
    sub      <= cmd_word(3 downto 2);
    rx_full  <= '1' when unsigned(rx_bits_i) = SPI_WIDTH else '0';

    rd_req   <= '1' when spi_state_reg = S_IDLE and rx_valid_i = '1' and rx_full = '1' and op = OP_READ else '0';
    wr_req   <= '1' when spi_state_reg = S_IDLE and rx_valid_i = '1' and rx_full = '1' and op = OP_WRITE else '0';
    bus_done <= '1' when bus_state_reg = B_BUSY and (ack_i or err_i) = '1' else '0';

    spi_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                spi_state_reg <= S_IDLE;
                ready_reg     <= '1';
                halt_reg      <= '0';
                resp_reg      <= (others => '0');
            else
                case spi_state_reg is
                    when S_IDLE =>
                        if rx_valid_i = '1' and rx_full = '1' then
                            case op is
                                when OP_READ | OP_WRITE =>
                                    spi_state_reg <= S_EXEC;
                                    ready_reg     <= '0';
                                when OP_CTRL =>
                                    spi_state_reg <= S_CTRL;
                                    ready_reg     <= '0';
                                when OP_NOP =>
                                    null;
                                when others =>
                                    null;
                            end case;
                        end if;
                    when S_EXEC =>
                        if bus_done = '1' then
                            spi_state_reg <= S_IDLE;
                            ready_reg     <= '1';
                            if we_reg = '0' and ack_i = '1' then
                                resp_reg <= dat_i;
                            else
                                resp_reg <= (others => '0');
                            end if;
                        end if;
                    when S_CTRL =>
                        spi_state_reg <= S_IDLE;
                        ready_reg     <= '1';
                        case sub is
                            when SUB_RUN =>
                                halt_reg <= '0';
                                resp_reg <= (others => '0');
                            when SUB_HALT =>
                                halt_reg <= '1';
                                resp_reg <= (others => '0');
                            when SUB_ID =>
                                resp_reg <= DBG_ID;
                            when others =>
                                null;
                        end case;
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
                ack_reg       <= '0';
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
                            ack_reg       <= ack_i;
                            err_reg       <= err_i and not ack_i;
                        end if;
                end case;
            end if;
        end if;
    end process bus_proc;

    status <= ready_reg & ack_reg & err_reg & halt_reg & (SOC_DATA_WIDTH-5 downto 0 => '0');

    tx_valid_o <= '1';
    tx_data_o  <= status & resp_reg;
    cyc_o      <= cyc_reg;
    stb_o      <= stb_reg;
    we_o       <= we_reg;
    sel_o      <= (others => '1');
    adr_o      <= adr_reg;
    dat_o      <= dat_reg;
    halt_o     <= halt_reg;

end architecture rtl;
