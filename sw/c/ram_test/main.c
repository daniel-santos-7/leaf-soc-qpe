#include <stdint.h>
#include "../common/leaf.h"

extern char __end[];

#define STACK_HEADROOM  2048u
#define RAM_TOP         (0x80000000u + 0x4000u)

static uint32_t checksum;

static void acc(uint32_t v)
{
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

    uart_puts("ram_test start\n");

    base = ((uint32_t)__end + 3u) & ~3u;
    top  = RAM_TOP - STACK_HEADROOM;
    span = top - base;

    uart_puts("window ");
    put_hex(base);
    uart_puts(" .. ");
    put_hex(top);
    uart_puts("\n");

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
