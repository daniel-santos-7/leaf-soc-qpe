import sys

PACKAGE_TEMPLATE ='''library IEEE;
use IEEE.std_logic_1164.all;

package boot_pkg is

    constant BOOT_SIZE : natural := {boot_size};

    type byte_array is array (0 to BOOT_SIZE-1) of std_logic_vector(7 downto 0);

    constant BOOT_DATA : byte_array := ({boot_data}\n\t);

end package boot_pkg;'''

if __name__ == '__main__':
    argv_len = len(sys.argv)
    if argv_len == 1:
        print("Usage: python boot.py")
        exit(1)
    bin_file = sys.argv[1]
    with open(bin_file, "rb") as f:
        data = f.read()
        boot_data = ",".join([f'\n\t{i} => x"{b:02X}"' for i, b in enumerate(data)])
        package = PACKAGE_TEMPLATE.format(boot_size=len(data), boot_data=boot_data)
        print(package)
