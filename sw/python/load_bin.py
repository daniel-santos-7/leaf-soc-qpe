#!/usr/bin/env python3
"""
Leaf SoC UART Bootloader

Loads a binary program into Leaf RISC-V SoC via UART using the
RAM_LOAD / RAM_JUMP protocol.

Usage:
    python3 load_bin.py <port> <binary> [baud]
"""

import sys
import serial
import struct
import time

RAM_LOAD_CMD = 0x4C
RAM_JUMP_CMD = 0x4A
ACK = 0x06
NAK = 0x15
CRC_POLYNOMIAL = 0x07
ACK_TIMEOUT = 0.02


def calc_crc(data, crc_in, polynomial):
    """CRC-8 implementation matching VHDL leaf_soc_tb_pkg.calc_crc"""
    crc = crc_in
    for byte in data:
        for i in range(7, -1, -1):
            bit = (byte >> i) & 1
            if crc & 0x80:
                crc = ((crc << 1) & 0xFF) ^ polynomial
            else:
                crc = (crc << 1) & 0xFF
            if bit:
                crc ^= polynomial
    return crc


def load_bin(port, filename, baud=115200):
    with open(filename, 'rb') as f:
        program_data = f.read()
    program_size = len(program_data)

    print(f"Loading {filename} ({program_size} bytes) to {port} @ {baud} baud")

    ser = serial.Serial(port, baud, timeout=1)
    time.sleep(0.1)

    print(f"Sending RAM_LOAD_CMD (0x{RAM_LOAD_CMD:02X})...")
    ser.write(bytes([RAM_LOAD_CMD]))
    ser.flush()

    if not wait_ack(ser):
        print("ERROR: No ACK after RAM_LOAD_CMD")
        return False

    size_bytes = struct.pack('<I', program_size)
    crc = 0x00
    for b in size_bytes:
        crc = calc_crc([b], crc, CRC_POLYNOMIAL)

    print(f"Sending size: {program_size} ({' '.join(f'0x{b:02X}' for b in size_bytes)})")
    ser.write(size_bytes)
    ser.flush()

    ser.write(bytes([crc]))
    ser.flush()

    if not wait_ack(ser):
        print("ERROR: No ACK after size+CRC")
        return False

    print(f"Sending {program_size} program bytes...")
    crc = 0x00
    for i, b in enumerate(program_data):
        ser.write(bytes([b]))
        ser.flush()
        crc = calc_crc([b], crc, CRC_POLYNOMIAL)
        if (i + 1) % 1024 == 0:
            print(f"  Progress: {i+1}/{program_size} bytes")

    ser.write(bytes([crc]))
    ser.flush()

    if not wait_ack(ser):
        print("ERROR: No ACK after program data")
        return False

    print(f"Sending RAM_JUMP_CMD (0x{RAM_JUMP_CMD:02X})...")
    ser.write(bytes([RAM_JUMP_CMD]))
    ser.flush()

    if not wait_ack(ser):
        print("ERROR: No ACK after RAM_JUMP_CMD")
        return False

    print("SUCCESS: Program loaded and started!")
    ser.close()
    return True


def wait_ack(ser):
    start = time.time()
    while time.time() - start < ACK_TIMEOUT:
        if ser.in_waiting:
            b = ser.read(1)
            if b[0] == ACK:
                return True
            elif b[0] == NAK:
                print(f"WARNING: Got NAK (0x{NAK:02X})")
                return False
        time.sleep(0.001)
    return False


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    port = sys.argv[1]
    filename = sys.argv[2]
    baud = int(sys.argv[3]) if len(sys.argv) > 3 else 115200

    success = load_bin(port, filename, baud)
    sys.exit(0 if success else 1)