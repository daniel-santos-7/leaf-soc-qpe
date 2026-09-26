#include <stdio.h>
#include <stdint.h>

#define RAM0_BASE  0x80000000u
#define XIP_BASE   0x20000000u

__attribute__((noinline)) static uint32_t scramble(uint32_t n) {
	uint32_t s = 0x12345678u, i;
	for (i = 1; i <= n; i++)
		s = ((s << 3) | (s >> 29)) ^ i;
	return s;
}

int main(void) {
	uint32_t (*xip_scramble)(uint32_t) =
		(uint32_t (*)(uint32_t))((uintptr_t)scramble - RAM0_BASE + XIP_BASE);
	uint32_t ram = scramble(10);
	uint32_t xip = xip_scramble(10);

	printf("XIP ram=%08lx xip=%08lx %s\n", (unsigned long)ram, (unsigned long)xip,
	       ram == xip ? "ok" : "FAIL");

	return 0;
}
