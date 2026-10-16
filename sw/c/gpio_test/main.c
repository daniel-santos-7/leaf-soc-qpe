#include <stdio.h>
#include <stdint.h>

#include "../common/gpio.h"

static volatile uint32_t irq_count;
static volatile uint32_t irq_status;
static volatile uint32_t irq_cause;

__attribute__((interrupt("machine"))) static void trap_handler(void) {
	uint32_t cause;
	__asm__ volatile ("csrr %0, mcause" : "=r"(cause));
	irq_cause = cause;
	irq_status = gpio_get_irq_status();
	gpio_clr_irq_status(irq_status);
	irq_count++;
}

int main(void) {
	uint32_t i;

	gpio_set_dir(0x0F);
	gpio_set_out(0x0A);
	printf("GPIO out=0a in=%02lx\n", (unsigned long)gpio_get_in());
	gpio_set_bits(0x05);
	printf("GPIO set=05 in=%02lx\n", (unsigned long)gpio_get_in());
	gpio_clr_bits(0x03);
	printf("GPIO clr=03 in=%02lx\n", (unsigned long)gpio_get_in());
	gpio_tgl_bits(0x09);
	printf("GPIO tgl=09 in=%02lx\n", (unsigned long)gpio_get_in());

	__asm__ volatile ("csrw mtvec, %0" :: "r"(trap_handler));
	__asm__ volatile ("csrs mie, %0" :: "r"(1u << 11));
	__asm__ volatile ("csrs mstatus, %0" :: "r"(1u << 3));

	gpio_set_irq_rise(0x02);
	gpio_set_bits(0x02);
	for (i = 0; i < 1000 && irq_count == 0; i++)
		;

	printf("GPIO irq count=%lu status=%02lx mcause=%08lx pending=%02lx\n",
	       (unsigned long)irq_count, (unsigned long)irq_status,
	       (unsigned long)irq_cause, (unsigned long)gpio_get_irq_status());

	return 0;
}
