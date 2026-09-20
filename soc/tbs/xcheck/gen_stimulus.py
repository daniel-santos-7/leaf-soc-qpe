#!/usr/bin/env python3
"""Generate one shared stimulus vector file for the macro equivalence bench.

One line per clock cycle, decimal fields:

    AA DA BWEBA WEBA CEBA AB DB BWEBB WEBB CEBB

The address space is deliberately tiny (ADDR_SPAN) so that the two ports collide
often and the read/write, write/read and write/write contention paths actually
get exercised.
"""

import random
import sys

CYCLES = int(sys.argv[1]) if len(sys.argv) > 1 else 4000
SEED = int(sys.argv[2]) if len(sys.argv) > 2 else 1
ADDR_SPAN = 16

random.seed(SEED)


def mask():
    """Active-low per-bit write mask, biased towards whole/byte lane writes."""
    r = random.random()
    if r < 0.45:
        return 0x0000            # write all 16 bits
    if r < 0.65:
        return 0xFF00            # low byte only
    if r < 0.85:
        return 0x00FF            # high byte only
    return random.getrandbits(16)


with open("stimulus.txt", "w") as f:
    for _ in range(CYCLES):
        ceba = 0 if random.random() < 0.85 else 1
        cebb = 0 if random.random() < 0.85 else 1
        weba = 0 if random.random() < 0.40 else 1
        webb = 0 if random.random() < 0.40 else 1
        f.write(
            "%d %d %d %d %d %d %d %d %d %d\n"
            % (
                random.randrange(ADDR_SPAN),
                random.getrandbits(16),
                mask() if weba == 0 else 0xFFFF,
                weba,
                ceba,
                random.randrange(ADDR_SPAN),
                random.getrandbits(16),
                mask() if webb == 0 else 0xFFFF,
                webb,
                cebb,
            )
        )

print("stimulus.txt: %d cycles, seed %d" % (CYCLES, SEED))
