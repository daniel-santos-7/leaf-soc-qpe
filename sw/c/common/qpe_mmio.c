#include "qpe_mmio.h"
#include "leaf.h"

#define QPE_MMIO_REG32(off) (*(volatile uint32_t *)(QPE_MMIO_BASE + (off)))
#define QPE_MMIO_REG16(off) (*(volatile uint16_t *)(QPE_MMIO_BASE + (off)))

void qpe_mmio_set_ftw(uint32_t val)
{
    QPE_MMIO_REG32(QPE_MMIO_OFF_FTW) = val;
}

void qpe_mmio_set_pow(uint32_t val)
{
    QPE_MMIO_REG32(QPE_MMIO_OFF_POW) = val;
}

void qpe_mmio_set_amp(uint16_t val)
{
    QPE_MMIO_REG16(QPE_MMIO_OFF_AMP) = val;
}

void qpe_mmio_set_drag(uint16_t val)
{
    QPE_MMIO_REG16(QPE_MMIO_OFF_DRAG) = val;
}

void qpe_mmio_set_env(uint32_t val)
{
    QPE_MMIO_REG32(QPE_MMIO_OFF_ENV) = val;
}

void qpe_mmio_set_delay(uint32_t val)
{
    QPE_MMIO_REG32(QPE_MMIO_OFF_DELAY) = val;
}

uint32_t qpe_mmio_get_ftw(void)
{
    return QPE_MMIO_REG32(QPE_MMIO_OFF_FTW);
}

uint32_t qpe_mmio_get_pow(void)
{
    return QPE_MMIO_REG32(QPE_MMIO_OFF_POW);
}

uint16_t qpe_mmio_get_amp(void)
{
    return (uint16_t)QPE_MMIO_REG32(QPE_MMIO_OFF_AMP);
}

uint32_t qpe_mmio_get_env(void)
{
    return QPE_MMIO_REG32(QPE_MMIO_OFF_ENV);
}

uint16_t qpe_mmio_get_drag(void)
{
    return (uint16_t)QPE_MMIO_REG32(QPE_MMIO_OFF_DRAG);
}

uint32_t qpe_mmio_get_delay(void)
{
    return QPE_MMIO_REG32(QPE_MMIO_OFF_DELAY);
}

void qpe_mmio_trigger(void)
{
    QPE_MMIO_REG32(QPE_MMIO_OFF_TRIG) = 1;
}

int qpe_mmio_is_ready(void)
{
    return (QPE_MMIO_REG32(QPE_MMIO_OFF_TRIG) & (1u << 1)) != 0;
}

int qpe_mmio_is_valid(void)
{
    return (QPE_MMIO_REG32(QPE_MMIO_OFF_TRIG) & (1u << 0)) != 0;
}

void qpe_mmio_wait_ready(void)
{
    while (!qpe_mmio_is_ready());
}

void qpe_mmio_configure(const qpe_mmio_pulse_t *p)
{
    qpe_mmio_set_ftw(p->ftw);
    qpe_mmio_set_pow(p->pow);
    qpe_mmio_set_amp(p->amp);
    qpe_mmio_set_env(p->env);
    qpe_mmio_set_drag(p->drag);
    qpe_mmio_set_delay(p->delay);
}

void qpe_mmio_pulse(const qpe_mmio_pulse_t *p)
{
    qpe_mmio_configure(p);
    qpe_mmio_trigger();
}

void qpe_mmio_init(void)
{
    if (!qpe_mmio_is_ready()) {
        uart_puts("QPE MMIO: no pulse generator on IO1, is this a COP SoC?\n");
        for (;;);
    }
}
