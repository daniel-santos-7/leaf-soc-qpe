library IEEE;
use IEEE.std_logic_1164.all;

package leaf_soc_pkg is
    
    component soc_syscon is
        port (
            clk   : in  std_logic;
            rst   : in  std_logic;
            clk_o : out std_logic;
            rst_o : out std_logic
        );
    end component soc_syscon;

    component ram is
        generic (
            BITS : natural := 8
        );
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            dat_i : in  std_logic_vector(31 downto 0);
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            sel_i : in  std_logic_vector(3  downto 0);        
            adr_i : in  std_logic_vector(BITS-3 downto 0);
            ack_o : out std_logic;
            dat_o : out std_logic_vector(31 downto 0)
        );
    end component ram;

    component rom is
        generic (
            BITS : natural := 8
        );
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            adr_i : in  std_logic_vector(BITS-3 downto 0);
            ack_o : out std_logic;
            dat_o : out std_logic_vector(31 downto 0)
        );
    end component rom;

    component leaf_soc is
        port (
            clk : in  std_logic;
            rst : in  std_logic;
            rx  : in  std_logic;
            tx  : out std_logic;
            dbg : out std_logic_vector(7 downto 0)
        );
    end component leaf_soc;

    component debug_reg is
        port (
            clk_i : in  std_logic;
            rst_i : in  std_logic;
            dat_i : in  std_logic_vector(7 downto 0);
            cyc_i : in  std_logic;
            stb_i : in  std_logic;
            we_i  : in  std_logic;
            ack_o : out std_logic;
            dat_o : out std_logic_vector(7 downto 0)
        );
    end component debug_reg;

    component wb_intercon is
        port (
            cpu_cyc_i  : in   std_logic;
            cpu_stb_i  : in   std_logic;
            cpu_we_i   : in   std_logic;
            cpu_sel_i  : in   std_logic_vector(3  downto 0);
            cpu_adr_i  : in   std_logic_vector(31 downto 0);
            cpu_dat_i  : in   std_logic_vector(31 downto 0);
            uart_ack_i : in   std_logic;
            rom_ack_i  : in   std_logic;
            ram_ack_i  : in   std_logic;
            dbg_ack_i  : in   std_logic;
            uart_err_i : in   std_logic;
            rom_err_i  : in   std_logic;
            ram_err_i  : in   std_logic;
            dbg_err_i  : in   std_logic;
            uart_dat_i : in   std_logic_vector(31 downto 0);
            rom_dat_i  : in   std_logic_vector(31 downto 0);
            ram_dat_i  : in   std_logic_vector(31 downto 0);
            dbg_dat_i  : in   std_logic_vector(7  downto 0);
            cpu_ack_o  : out  std_logic;
            cpu_err_o  : out  std_logic;
            uart_cyc_o : out  std_logic;
            rom_cyc_o  : out  std_logic;
            ram_cyc_o  : out  std_logic;
            dbg_cyc_o  : out  std_logic;
            uart_stb_o : out  std_logic;
            rom_stb_o  : out  std_logic;
            ram_stb_o  : out  std_logic;
            dbg_stb_o  : out  std_logic;
            uart_we_o  : out  std_logic;
            rom_we_o   : out  std_logic;
            ram_we_o   : out  std_logic;
            dbg_we_o   : out  std_logic;
            uart_sel_o : out  std_logic_vector(3  downto 0);
            rom_sel_o  : out  std_logic_vector(3  downto 0);
            ram_sel_o  : out  std_logic_vector(3  downto 0);
            dbg_sel_o  : out  std_logic_vector(3  downto 0);
            uart_adr_o : out  std_logic_vector(1  downto 0);
            ram_adr_o  : out  std_logic_vector(13 downto 0);
            rom_adr_o  : out  std_logic_vector(5  downto 0);
            dbg_adr_o  : out  std_logic_vector(31 downto 0);
            cpu_dat_o  : out  std_logic_vector(31 downto 0);
            uart_dat_o : out  std_logic_vector(31 downto 0);
            rom_dat_o  : out  std_logic_vector(31 downto 0);
            ram_dat_o  : out  std_logic_vector(31 downto 0);
            dbg_dat_o  : out  std_logic_vector(7  downto 0)
        );
    end component wb_intercon;
    
end package leaf_soc_pkg;