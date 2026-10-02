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
        active_i   : in  std_logic;
        rx_data_i  : in  std_logic_vector(7 downto 0);
        rx_valid_i : in  std_logic;
        tx_data_o  : out std_logic_vector(7 downto 0);
        tx_load_i  : in  std_logic;
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
        halt_o     : out std_logic;
        sig_src_o  : out std_logic;
        sig_i_o    : out std_logic_vector(OUT_RES_BITS-1 downto 0);
        sig_q_o    : out std_logic_vector(OUT_RES_BITS-1 downto 0)
    );
end entity wb_dbg_ctrl;

architecture rtl of wb_dbg_ctrl is

    constant CMD_WRITE  : std_logic_vector(7 downto 0) := x"01";
    constant CMD_READ   : std_logic_vector(7 downto 0) := x"02";
    constant CMD_STATUS : std_logic_vector(7 downto 0) := x"03";
    constant CMD_CTRL   : std_logic_vector(7 downto 0) := x"04";
    constant CMD_ID     : std_logic_vector(7 downto 0) := x"05";
    constant CMD_SIG    : std_logic_vector(7 downto 0) := x"06";

    type bus_state_t is (B_IDLE, B_REQ, B_WAIT);
    signal bus_state : bus_state_t;

    signal byte_cnt : unsigned(3 downto 0);
    signal tx_byte  : std_logic_vector(7 downto 0);

    signal cmd_reg   : std_logic_vector(7 downto 0);
    signal addr_reg  : std_logic_vector(SOC_ADDR_WIDTH-1 downto 0);
    signal wdata_reg : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal rdata_reg : std_logic_vector(SOC_DATA_WIDTH-1 downto 0);
    signal we_reg    : std_logic;

    signal halt_reg  : std_logic;
    signal src_reg   : std_logic;
    signal sig_i_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sig_q_reg : std_logic_vector(OUT_RES_BITS-1 downto 0);
    signal sig_word  : std_logic_vector(39 downto 0);
    signal err_reg   : std_logic;
    signal ovr_reg   : std_logic;
    signal busy      : std_logic;
    signal status    : std_logic_vector(7 downto 0);

    signal start_wr  : std_logic;
    signal start_rd  : std_logic;
    signal status_rd : std_logic;

begin

    assert OUT_RES_BITS <= 16 report "wb_dbg_ctrl: OUT_RES_BITS must fit in 16 bits" severity failure;

    sig_word <= wdata_reg & rx_data_i;

    start_wr  <= '1' when rx_valid_i = '1' and cmd_reg = CMD_WRITE and byte_cnt = 8 else '0';
    start_rd  <= '1' when rx_valid_i = '1' and cmd_reg = CMD_READ and byte_cnt = 4 else '0';
    status_rd <= '1' when tx_load_i = '1' and cmd_reg = CMD_STATUS and byte_cnt = 1 else '0';

    frame_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                byte_cnt  <= (others => '0');
                cmd_reg   <= (others => '0');
                addr_reg  <= (others => '0');
                wdata_reg <= (others => '0');
                halt_reg  <= '0';
                src_reg   <= '0';
                sig_i_reg <= (others => '0');
                sig_q_reg <= (others => '0');
            elsif active_i = '0' then
                byte_cnt <= (others => '0');
                cmd_reg  <= (others => '0');
            elsif rx_valid_i = '1' then
                if byte_cnt /= 15 then
                    byte_cnt <= byte_cnt + 1;
                end if;
                if byte_cnt = 0 then
                    cmd_reg <= rx_data_i;
                end if;
                if (cmd_reg = CMD_WRITE or cmd_reg = CMD_READ) and byte_cnt >= 1 and byte_cnt <= 4 then
                    addr_reg <= addr_reg(SOC_ADDR_WIDTH-9 downto 0) & rx_data_i;
                end if;
                if cmd_reg = CMD_WRITE and byte_cnt >= 5 and byte_cnt <= 8 then
                    wdata_reg <= wdata_reg(SOC_DATA_WIDTH-9 downto 0) & rx_data_i;
                end if;
                if cmd_reg = CMD_SIG and byte_cnt >= 1 and byte_cnt <= 4 then
                    wdata_reg <= wdata_reg(SOC_DATA_WIDTH-9 downto 0) & rx_data_i;
                end if;
                if cmd_reg = CMD_SIG and byte_cnt = 5 then
                    src_reg   <= sig_word(32);
                    sig_i_reg <= sig_word(16+OUT_RES_BITS-1 downto 16);
                    sig_q_reg <= sig_word(OUT_RES_BITS-1 downto 0);
                end if;
                if cmd_reg = CMD_CTRL and byte_cnt = 1 then
                    halt_reg <= rx_data_i(0);
                end if;
            end if;
        end if;
    end process frame_proc;

    busy   <= '0' when bus_state = B_IDLE else '1';
    status <= "000" & src_reg & ovr_reg & busy & err_reg & halt_reg;

    tx_proc: process(cmd_reg, byte_cnt, rdata_reg, status)
    begin
        tx_byte <= (others => '0');
        if cmd_reg = CMD_READ then
            case to_integer(byte_cnt) is
                when 6      => tx_byte <= rdata_reg(31 downto 24);
                when 7      => tx_byte <= rdata_reg(23 downto 16);
                when 8      => tx_byte <= rdata_reg(15 downto 8);
                when 9      => tx_byte <= rdata_reg(7 downto 0);
                when 10     => tx_byte <= status;
                when others => tx_byte <= (others => '0');
            end case;
        elsif cmd_reg = CMD_STATUS then
            if byte_cnt = 1 then
                tx_byte <= status;
            end if;
        elsif cmd_reg = CMD_ID then
            case to_integer(byte_cnt) is
                when 1      => tx_byte <= DBG_ID(31 downto 24);
                when 2      => tx_byte <= DBG_ID(23 downto 16);
                when 3      => tx_byte <= DBG_ID(15 downto 8);
                when 4      => tx_byte <= DBG_ID(7 downto 0);
                when others => tx_byte <= (others => '0');
            end case;
        end if;
    end process tx_proc;

    bus_proc: process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                bus_state <= B_IDLE;
                we_reg    <= '0';
                rdata_reg <= (others => '0');
                err_reg   <= '0';
                ovr_reg   <= '0';
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
                            if we_reg = '0' then
                                if ack_i = '1' then
                                    rdata_reg <= dat_i;
                                else
                                    rdata_reg <= (others => '0');
                                end if;
                            end if;
                        end if;
                end case;
                if (start_wr or start_rd) = '1' and bus_state /= B_IDLE then
                    ovr_reg <= '1';
                elsif status_rd = '1' then
                    ovr_reg <= '0';
                end if;
            end if;
        end if;
    end process bus_proc;

    tx_data_o <= tx_byte;

    cyc_o  <= busy;
    stb_o  <= '1' when bus_state = B_REQ else '0';
    we_o   <= we_reg;
    sel_o  <= (others => '1');
    adr_o  <= addr_reg(SOC_ADDR_WIDTH-1 downto 2);
    dat_o  <= wdata_reg;
    halt_o <= halt_reg;

    sig_src_o <= src_reg;
    sig_i_o   <= sig_i_reg;
    sig_q_o   <= sig_q_reg;

end architecture rtl;
