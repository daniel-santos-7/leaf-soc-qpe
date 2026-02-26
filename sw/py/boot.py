with open("../boot/boot.bin", "rb") as f:
    data = f.read()

with open("rom_pkg.vhdl", "w") as vhd:
    vhd.write("library IEEE;\n")
    vhd.write("use IEEE.std_logic_1164.all;\n")
    vhd.write("use IEEE.numeric_std.all;\n\n")
    vhd.write("package rom_pkg is\n")
    vhd.write(f"\tconstant ROM_SIZE : integer := {len(data)};\n")
    vhd.write("\ttype rom_t is array (0 to ROM_SIZE-1) of std_logic_vector(7 downto 0);\n")
    vhd.write("\tconstant ROM : rom_t := (\n")
    for i, b in enumerate(data):
        sep = "," if i < len(data)-1 else ""
        vhd.write(f'\t\t{i} => x"{b:02X}"{sep}\n')
    vhd.write("\t);\n")
    vhd.write("end package rom_pkg;\n")
