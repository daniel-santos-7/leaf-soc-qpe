----------------------------------------------------------------------
-- Leaf project
-- developed by: Daniel Santos
-- module: fifo
-- description: generic circular buffer
----------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fifo is
    generic (
        FIFO_DEPTH : natural := 8;
        DATA_WIDTH : natural := 8
    );
    port (
        clk_i : in  std_logic;
        rst_i : in  std_logic;
        vld_i : in  std_logic;
        rdy_i : in  std_logic;
        dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        vld_o : out std_logic;
        rdy_o : out std_logic;
        dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity fifo;

architecture rtl of fifo is

    ----------------------------- types ----------------------------------

    type fifo_data_array is array (0 to FIFO_DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);

    constant READ_OP  : std_logic := '0';
    constant WRITE_OP : std_logic := '1';

    ---------------------------- fifo data -------------------------------

    signal fifo_data: fifo_data_array;

    --------------------- fifo last op register --------------------------

    signal last_op: std_logic;

    ---------------------------- pointers --------------------------------

    signal wr_pointer: integer range 0 to FIFO_DEPTH-1;
    signal rd_pointer: integer range 0 to FIFO_DEPTH-1;

    ------------------------- internal flags -----------------------------

    signal empty: std_logic;
    signal full:  std_logic;

begin

    ---------------------- read data from fifo ---------------------------

    dat_o <= fifo_data(rd_pointer);

    read_data: process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            rd_pointer <= 0;
        elsif rising_edge(clk_i) then
            if rdy_i = '1' and empty = '0' then
                rd_pointer <= (rd_pointer + 1) mod FIFO_DEPTH;
            end if;
        end if;
    end process read_data;

    ------------------------ write data on fifo --------------------------

    write_data: process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            fifo_data <= (others => (others => '0'));
            wr_pointer <= 0;
        elsif rising_edge(clk_i) then
            if vld_i = '1' and full = '0' then
                fifo_data(wr_pointer) <= dat_i;
                wr_pointer <= (wr_pointer + 1) mod FIFO_DEPTH;
            end if;
        end if;
    end process write_data;

    --------------------- last operation storage -------------------------

    save_last_op: process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            last_op <= READ_OP;
        elsif rising_edge(clk_i) then
            if rdy_i = '1' and vld_i = '0' then
                last_op <= READ_OP;
            elsif rdy_i = '0' and vld_i = '1' then
                last_op <= WRITE_OP;
            end if;
        end if;
    end process save_last_op;

    ------------------------- internal flags -----------------------------

    empty <= '1' when wr_pointer = rd_pointer and last_op = READ_OP  else '0';
    full  <= '1' when wr_pointer = rd_pointer and last_op = WRITE_OP else '0';

    -------------------------- output flags -------------------------------

    vld_o <= not empty;
    rdy_o <= not full;

end architecture rtl;
