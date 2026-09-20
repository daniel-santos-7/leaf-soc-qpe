/*
 * RAM exercise: walks every bank of the 32 KB RAM with word, half-word and
 * byte accesses, reads everything back and reports a checksum over the UART.
 *
 * Written to tell the behavioural RAM and the TSMC macro array apart if they
 * ever disagree.  The things it deliberately stresses are exactly the places
 * where wb_ram_dp_tsmc does work that wb_ram_dp gets for free:
 *
 *   - addresses spread across all four macro banks, so the bank decode and the
 *     registered read mux are exercised (a stuck mux shows up as data from the
 *     wrong bank);
 *   - sub-word stores, so sel_i -> BWEB per-bit masking is exercised (a wrong
 *     mask corrupts neighbouring bytes, which the read-back catches);
 *   - a read immediately after a write to the same address, because the macro
 *     has no write-through and Q only moves on a read cycle.
 *
 * The checksum is order-dependent, so a single wrong byte changes it.
 */

#include <stdint.h>
#include "../common/leaf.h"

extern char __end[];

/* Stay clear of the program image below and the stack above. */
#define STACK_HEADROOM  2048u
#define RAM_TOP         (0x80000000u + 0x8000u)

static uint32_t checksum;

static void acc(uint32_t v)
{
    /* Rotate-and-xor.  Order-dependent, so a byte that lands at the wrong
       address changes the result instead of cancelling out.  Deliberately free
       of multiplication: this is rv32i, so `*=` would expand into a software
       multiply routine and acc() is on the hot path of every pass. */
    checksum = (checksum << 5) | (checksum >> 27);
    checksum ^= v;
}

static void put_hex(uint32_t v)
{
    const char digits[] = "0123456789ABCDEF";
    char buf[9];
    int i;

    for (i = 7; i >= 0; i--) {
        buf[i] = digits[v & 0xF];
        v >>= 4;
    }
    buf[8] = '\0';
    uart_puts(buf);
}

void main(void)
{
    volatile uint32_t *w;
    volatile uint16_t *h;
    volatile uint8_t  *b;
    uint32_t base, top, addr, span, i, expect;
    uint32_t errors = 0;

    /* No uart_init here on purpose: the UART is already running at the rate
       the boot ROM set up, and rewriting the baud divisor would corrupt the
       ACK the bootloader still has in flight when it jumps into RAM. */
    uart_puts("ram_test start\n");

    base = ((uint32_t)__end + 3u) & ~3u;
    top  = RAM_TOP - STACK_HEADROOM;
    span = top - base;

    uart_puts("window ");
    put_hex(base);
    uart_puts(" .. ");
    put_hex(top);
    uart_puts("\n");

    /* --- pass 1: word stores across every bank ------------------------- */
    for (addr = base; addr + 4u <= top; addr += 4u) {
        w = (volatile uint32_t *)addr;
        *w = addr ^ 0xA5A5A5A5u;
    }
    for (addr = base; addr + 4u <= top; addr += 4u) {
        w = (volatile uint32_t *)addr;
        expect = addr ^ 0xA5A5A5A5u;
        if (*w != expect) {
            errors++;
        }
        acc(*w);
    }
    uart_puts("pass1 words done\n");

    /* --- pass 2: byte stores, one lane at a time ----------------------- */
    /* Every fourth word, so all four sel_i single-lane patterns are driven
       many times in each bank.  A bad write mask is the same logic for every
       address, so sampling proves it; pass 1 is what covers the address
       space.                                                               */
    for (addr = base; addr + 4u <= top; addr += 16u) {
        b = (volatile uint8_t *)addr;
        for (i = 0; i < 4u; i++) {
            b[i] = (uint8_t)((addr >> (8u * i)) + i);
        }
    }
    for (addr = base; addr + 4u <= top; addr += 16u) {
        b = (volatile uint8_t *)addr;
        for (i = 0; i < 4u; i++) {
            if (b[i] != (uint8_t)((addr >> (8u * i)) + i)) {
                errors++;
            }
            acc(b[i]);
        }
    }
    uart_puts("pass2 bytes done\n");

    /* --- pass 3: half-word stores -------------------------------------- */
    for (addr = base; addr + 4u <= top; addr += 16u) {
        h = (volatile uint16_t *)addr;
        h[0] = (uint16_t)(addr >> 2);
        h[1] = (uint16_t)(~(addr >> 2));
    }
    for (addr = base; addr + 4u <= top; addr += 16u) {
        h = (volatile uint16_t *)addr;
        if (h[0] != (uint16_t)(addr >> 2) || h[1] != (uint16_t)(~(addr >> 2))) {
            errors++;
        }
        acc(((uint32_t)h[1] << 16) | h[0]);
    }
    uart_puts("pass3 halves done\n");

    /* --- pass 4: write then immediately read the same address ---------- */
    /* No write-through in the macro, so this checks the wrapper really does
       produce the stored value on the following cycle.                     */
    for (addr = base; addr + 4u <= top; addr += 64u) {
        w = (volatile uint32_t *)addr;
        *w = addr + 0x1234u;
        if (*w != addr + 0x1234u) {
            errors++;
        }
        acc(*w);
    }
    uart_puts("pass4 rw done\n");

    uart_puts("bytes  ");
    put_hex(span);
    uart_puts("\nchecksum ");
    put_hex(checksum);
    uart_puts("\nerrors ");
    put_hex(errors);
    uart_puts(errors == 0u ? "\nRAM TEST PASS\n" : "\nRAM TEST FAIL\n");

    while (1) {
    }
}
