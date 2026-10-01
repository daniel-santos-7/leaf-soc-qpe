#include "wgen.h"
#include "leaf.h"

#define WGEN_REG32(off) (*(volatile uint32_t *)(WGEN_BASE + (off)))
#define WGEN_REG16(off) (*(volatile uint16_t *)(WGEN_BASE + (off)))

void wgen_write_ftw(uint32_t val)
{
    WGEN_REG32(WGEN_OFF_FTW) = val;
}

void wgen_write_pow(uint32_t val)
{
    WGEN_REG32(WGEN_OFF_POW) = val;
}

void wgen_write_amp(uint16_t val)
{
    WGEN_REG16(WGEN_OFF_AMP) = val;
}

void wgen_write_drag(uint16_t val)
{
    WGEN_REG16(WGEN_OFF_DRAG) = val;
}

void wgen_write_env(uint32_t val)
{
    WGEN_REG32(WGEN_OFF_ENV) = val;
}

void wgen_write_delay(uint32_t val)
{
    WGEN_REG32(WGEN_OFF_DELAY) = val;
}

uint32_t wgen_read_ftw(void)
{
    return WGEN_REG32(WGEN_OFF_FTW);
}

uint32_t wgen_read_pow(void)
{
    return WGEN_REG32(WGEN_OFF_POW);
}

uint16_t wgen_read_amp(void)
{
    return (uint16_t)WGEN_REG32(WGEN_OFF_AMP);
}

uint32_t wgen_read_env(void)
{
    return WGEN_REG32(WGEN_OFF_ENV);
}

uint16_t wgen_read_drag(void)
{
    return (uint16_t)WGEN_REG32(WGEN_OFF_DRAG);
}

uint32_t wgen_read_delay(void)
{
    return WGEN_REG32(WGEN_OFF_DELAY);
}

void wgen_trigger(void)
{
    WGEN_REG32(WGEN_OFF_TRIG) = 1;
}

int wgen_is_ready(void)
{
    return (WGEN_REG32(WGEN_OFF_TRIG) & (1u << 1)) != 0;
}

int wgen_is_valid(void)
{
    return (WGEN_REG32(WGEN_OFF_TRIG) & (1u << 0)) != 0;
}

void wgen_wait_ready(void)
{
    while (!wgen_is_ready());
}

void wgen_configure(const wgen_pulse_t *p)
{
    wgen_write_ftw(p->ftw);
    wgen_write_pow(p->pow);
    wgen_write_amp(p->amp);
    wgen_write_env(p->env);
    wgen_write_drag(p->drag);
    wgen_write_delay(p->delay);
}

void wgen_pulse(const wgen_pulse_t *p)
{
    wgen_configure(p);
    wgen_trigger();
}

void wgen_init(void)
{
    if (!wgen_is_ready()) {
        uart_puts("WGEN: no pulse generator on IO1, is this a COP SoC?\n");
        for (;;);
    }
}
