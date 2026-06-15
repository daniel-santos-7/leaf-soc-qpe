import sys

PACKAGE_TEMPLATE = '''library IEEE;
use IEEE.std_logic_1164.all;

package boot_pkg is

    constant INSTRUCTION_SIZE : natural := 32;

    type instruction_array is array (natural range <>) of std_logic_vector(INSTRUCTION_SIZE-1 downto 0);

    constant BOOT_DATA : instruction_array(0 to {boot_size}) := (
        {boot_data}
    );

end package boot_pkg;
'''

def format_array(data, dummy_data):
    instructions = []
    for i in range(0, len(data), 4):
        bytes = data[i:i+4]
        instruction = int.from_bytes(bytes, byteorder='little', signed=False)
        instructions.append(f'{i // 4} => x"{instruction:08X}"')
    if dummy_data:
        instructions.append(f'others => x"00000000"')
    return ",\n\t\t".join(instructions)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python boot.py <binary file> <memory size>", file=sys.stderr)
        sys.exit(1)

    bin_file = sys.argv[1]
    mem_size = int(sys.argv[2])

    with open(bin_file, "rb") as f:
        data = f.read()

        if len(data) > mem_size:
            print(f"ERROR: Binary size ({len(data)} bytes) exceeds memory size ({mem_size} bytes).", file=sys.stderr)
            sys.exit(1)

        if len(data) % 4 != 0:
            print(f"ERROR: Binary size ({len(data)} bytes) is not a multiple of 4.", file=sys.stderr)
            sys.exit(1)

        boot_size = mem_size // 4 - 1
        boot_data = format_array(data, len(data) < mem_size)

        package = PACKAGE_TEMPLATE.format(boot_size=boot_size, boot_data=boot_data)
        print(package)
