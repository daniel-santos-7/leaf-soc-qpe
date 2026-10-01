#include "qpe.h"
#include "leaf.h"

#define qpe_bind_set(addr, val) __asm__ volatile("csrwi %0, 5\n\tmv t0, %1\n\tcsrwi %0, 0" :: "i"(addr), "r"((uint32_t)(val)) : "t0")

void qpe_set_ftw(uint32_t val)
{
    qpe_bind_set(QPE_CSR_FTW, val);
}

void qpe_set_pow(uint32_t val)
{
    qpe_bind_set(QPE_CSR_POW, val);
}

void qpe_set_amp(uint16_t val)
{
    qpe_bind_set(QPE_CSR_AMP, val);
}

void qpe_set_drag(uint16_t val)
{
    qpe_bind_set(QPE_CSR_DRAG, val);
}

void qpe_set_env(uint32_t val)
{
    qpe_bind_set(QPE_CSR_ENV, val);
}

void qpe_set_delay(uint32_t val)
{
    qpe_bind_set(QPE_CSR_DELAY, val);
}

void qpe_trigger(void)
{
    __asm__ volatile("csrwi %0, 1" :: "i"(QPE_CSR_TRIG));
}

int qpe_is_ready(void)
{
    uint32_t v;
    __asm__ volatile("csrr %0, %1" : "=r"(v) : "i"(QPE_CSR_TRIG));
    return (v & (1u << 1)) != 0;
}

void qpe_wait_ready(void)
{
    while (!qpe_is_ready());
}

void qpe_configure(const qpe_pulse_t *p)
{
    qpe_set_ftw(p->ftw);
    qpe_set_pow(p->pow);
    qpe_set_amp(p->amp);
    qpe_set_env(p->env);
    qpe_set_drag(p->drag);
    qpe_set_delay(p->delay);
}

void qpe_pulse(const qpe_pulse_t *p)
{
    qpe_configure(p);
    qpe_trigger();
}

void qpe_init(void)
{
    if (!qpe_is_ready()) {
        uart_puts("QPE: no coprocessor, is this an MMIO SoC?\n");
        for (;;);
    }
}
