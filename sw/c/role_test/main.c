#include <stdio.h>
#include <stdint.h>

#define RAM1_BASE  0x90000000u
#define XIP_BASE   0x20000000u
#define XIP_CFG    (*(volatile uint32_t *)0x20FFFFFCu)
#define XIP_EN     0x00000001u
#define XIP_ACT    0x00000002u
#define ROLE_FLAG  (*(volatile uint32_t *)0x80000010u)
#define ROLE_RES   (*(volatile uint32_t *)0x80000014u)
#define ROLE_GO    0x600DF00Du
#define WAIT_FLAG  (*(volatile uint32_t *)0x80000018u)
#define WAIT_CAUSE (*(volatile uint32_t *)0x8000001Cu)
#define WAIT_CFG   (*(volatile uint32_t *)0x80000020u)
#define WAIT_RES   (*(volatile uint32_t *)0x80000024u)
#define WAIT_GO    0x5EC0DD00u

volatile uint32_t trap_cause;

__asm__(".section .text\n.align 2\n.globl trap_entry\ntrap_entry:\n"
        " csrr t0, mcause\n la t1, trap_cause\n sw t0, 0(t1)\n csrw mepc, ra\n mret\n");
extern void trap_entry(void);

__attribute__((noinline)) static uint32_t scramble(uint32_t n) {
	uint32_t s = 0x12345678u, i;
	for (i = 1; i <= n; i++)
		s = ((s << 3) | (s >> 29)) ^ i;
	return s;
}

int main(void) {
	uint32_t (*xip_scramble)(uint32_t) =
		(uint32_t (*)(uint32_t))((uintptr_t)scramble - RAM1_BASE + XIP_BASE);
	volatile uint32_t i;
	__asm__ volatile("csrw mtvec, %0" :: "r"(trap_entry));
	ROLE_FLAG = 0;
	ROLE_RES = 0;
	WAIT_FLAG = 0;
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

	while (WAIT_FLAG != WAIT_GO)
		;
	for (i = 0; i < 20; i++)
		;
	trap_cause = 0;
	XIP_CFG |= XIP_EN;
	xip_scramble(10);
	WAIT_CFG = XIP_CFG;
	WAIT_CAUSE = trap_cause;
	while (!(XIP_CFG & XIP_ACT))
		;
	xip = xip_scramble(10);
	XIP_CFG &= ~XIP_EN;
	WAIT_RES = xip;
	printf("WAIT cause=%lu cfg=%08lx xip=%08lx\n", (unsigned long)WAIT_CAUSE, (unsigned long)WAIT_CFG, (unsigned long)xip);

	return 0;
}
