#include <stdio.h>
#include <stdint.h>

#define GPIO_BASE        0x10002000u
#define GPIO_DATA_IN     (*(volatile uint32_t *)(GPIO_BASE + 0x00))
#define GPIO_DATA_OUT    (*(volatile uint32_t *)(GPIO_BASE + 0x04))
#define GPIO_DIR         (*(volatile uint32_t *)(GPIO_BASE + 0x08))
#define GPIO_SET         (*(volatile uint32_t *)(GPIO_BASE + 0x0C))
#define GPIO_CLR         (*(volatile uint32_t *)(GPIO_BASE + 0x10))
#define GPIO_TGL         (*(volatile uint32_t *)(GPIO_BASE + 0x14))
#define GPIO_IRQ_RISE    (*(volatile uint32_t *)(GPIO_BASE + 0x18))
#define GPIO_IRQ_FALL    (*(volatile uint32_t *)(GPIO_BASE + 0x1C))
#define GPIO_IRQ_STATUS  (*(volatile uint32_t *)(GPIO_BASE + 0x20))

static volatile uint32_t irq_count;
static volatile uint32_t irq_status;
static volatile uint32_t irq_cause;

__attribute__((interrupt("machine"))) static void trap_handler(void) {
	uint32_t cause;
	__asm__ volatile ("csrr %0, mcause" : "=r"(cause));
	irq_cause = cause;
	irq_status = GPIO_IRQ_STATUS;
	GPIO_IRQ_STATUS = irq_status;
	irq_count++;
}

int main(void) {
	uint32_t i;

	GPIO_DIR = 0x0F;
	GPIO_DATA_OUT = 0x0A;
	printf("GPIO out=0a in=%02lx\n", (unsigned long)GPIO_DATA_IN);
	GPIO_SET = 0x05;
	printf("GPIO set=05 in=%02lx\n", (unsigned long)GPIO_DATA_IN);
	GPIO_CLR = 0x03;
	printf("GPIO clr=03 in=%02lx\n", (unsigned long)GPIO_DATA_IN);
	GPIO_TGL = 0x09;
	printf("GPIO tgl=09 in=%02lx\n", (unsigned long)GPIO_DATA_IN);

	__asm__ volatile ("csrw mtvec, %0" :: "r"(trap_handler));
	__asm__ volatile ("csrs mie, %0" :: "r"(1u << 11));
	__asm__ volatile ("csrs mstatus, %0" :: "r"(1u << 3));

	GPIO_IRQ_RISE = 0x02;
	GPIO_SET = 0x02;
	for (i = 0; i < 1000 && irq_count == 0; i++)
		;

	printf("GPIO irq count=%lu status=%02lx mcause=%08lx pending=%02lx\n",
	       (unsigned long)irq_count, (unsigned long)irq_status,
	       (unsigned long)irq_cause, (unsigned long)GPIO_IRQ_STATUS);

	return 0;
}
