#include <stdio.h>
#include <stdint.h>

#define RAM0_BASE  0x80000000u
#define XIP_BASE   0x20000000u
#define XIP_CFG    (*(volatile uint32_t *)0x20FFFFFCu)
#define XIP_EN     0x00000001u
#define XIP_ACT    0x00000002u
#define ROLE_FLAG  (*(volatile uint32_t *)0x90000010u)
#define ROLE_RES   (*(volatile uint32_t *)0x90000014u)
#define ROLE_GO    0x600DF00Du

__attribute__((noinline)) static uint32_t scramble(uint32_t n) {
	uint32_t s = 0x12345678u, i;
	for (i = 1; i <= n; i++)
		s = ((s << 3) | (s >> 29)) ^ i;
	return s;
}

int main(void) {
	uint32_t (*xip_scramble)(uint32_t) =
		(uint32_t (*)(uint32_t))((uintptr_t)scramble - RAM0_BASE + XIP_BASE);
	ROLE_FLAG = 0;
	ROLE_RES = 0;
	printf("wait\n");
	while (ROLE_FLAG != ROLE_GO)
		;
	XIP_CFG |= XIP_EN;
	while (!(XIP_CFG & XIP_ACT))
		;
	uint32_t xip = xip_scramble(10);
	XIP_CFG &= ~XIP_EN;
	ROLE_RES = xip;
	printf("ROLE xip=%08lx\n", (unsigned long)xip);

	return 0;
}
