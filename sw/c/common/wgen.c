#include "wgen.h"

#ifdef WGEN_IF_MMIO

static volatile uint32_t *const wgen =
    (volatile uint32_t *)WGEN_BASE;

static inline uint32_t wgen_read(unsigned off)
{
    return *(volatile uint32_t *)((uintptr_t)wgen + off);
}

static inline void wgen_write(unsigned off, uint32_t val)
{
    *(volatile uint32_t *)((uintptr_t)wgen + off) = val;
}

#else

#define csr_write(addr, val) __asm__("csrw %0, %1" :: "i"(addr), "r"((uint32_t)(val)))
#define csr_read(addr) ({ uint32_t _v; __asm__("csrr %0, %1" : "=r"(_v) : "i"(addr)); _v; })

#endif

void wgen_write_ftw(uint32_t val)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_FTW, val);
#else
    csr_write(WGEN_CSR_FTW, val);
#endif
}

void wgen_write_pow(uint32_t val)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_POW, val);
#else
    csr_write(WGEN_CSR_POW, val);
#endif
}

void wgen_write_amp(uint16_t val)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_AMP, val);
#else
    csr_write(WGEN_CSR_AMP, val);
#endif
}

void wgen_write_env(uint32_t val)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_ENV, val);
#else
    csr_write(WGEN_CSR_ENV, val);
#endif
}

void wgen_write_drag(uint16_t val)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_DRAG, val);
#else
    csr_write(WGEN_CSR_DRAG, val);
#endif
}

void wgen_write_delay(uint32_t val)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_DELAY, val);
#else
    csr_write(WGEN_CSR_DELAY, val);
#endif
}

uint32_t wgen_read_ftw(void)
{
#ifdef WGEN_IF_MMIO
    return wgen_read(WGEN_OFF_FTW);
#else
    return csr_read(WGEN_CSR_FTW);
#endif
}

uint32_t wgen_read_pow(void)
{
#ifdef WGEN_IF_MMIO
    return wgen_read(WGEN_OFF_POW);
#else
    return csr_read(WGEN_CSR_POW);
#endif
}

uint16_t wgen_read_amp(void)
{
#ifdef WGEN_IF_MMIO
    return (uint16_t)wgen_read(WGEN_OFF_AMP);
#else
    return (uint16_t)csr_read(WGEN_CSR_AMP);
#endif
}

uint32_t wgen_read_env(void)
{
#ifdef WGEN_IF_MMIO
    return wgen_read(WGEN_OFF_ENV);
#else
    return csr_read(WGEN_CSR_ENV);
#endif
}

uint16_t wgen_read_drag(void)
{
#ifdef WGEN_IF_MMIO
    return (uint16_t)wgen_read(WGEN_OFF_DRAG);
#else
    return (uint16_t)csr_read(WGEN_CSR_DRAG);
#endif
}

uint32_t wgen_read_delay(void)
{
#ifdef WGEN_IF_MMIO
    return wgen_read(WGEN_OFF_DELAY);
#else
    return csr_read(WGEN_CSR_DELAY);
#endif
}

uint32_t wgen_read_trig(void)
{
#ifdef WGEN_IF_MMIO
    return wgen_read(WGEN_OFF_TRIG);
#else
    return csr_read(WGEN_CSR_TRIG);
#endif
}

void wgen_trigger(void)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_TRIG, 1);
#else
    csr_write(WGEN_CSR_TRIG, 1);
#endif
}

int wgen_is_ready(void)
{
    return (wgen_read_trig() & WGEN_TRIG_READY) != 0;
}

int wgen_is_valid(void)
{
    return (wgen_read_trig() & WGEN_TRIG_VALID) != 0;
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
