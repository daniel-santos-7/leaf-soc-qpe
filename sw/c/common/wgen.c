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

static uint32_t wgen_read_status(void)
{
#ifdef WGEN_IF_MMIO
    return wgen_read(WGEN_OFF_STAT);
#else
    return csr_read(WGEN_CSR_STAT);
#endif
}

void wgen_trigger(void)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_STAT, 1);
#else
    wgen_seq_set_len(1);
    wgen_seq_start();
#endif
}

int wgen_is_ready(void)
{
    return (wgen_read_status() & WGEN_STAT_READY) != 0;
}

int wgen_is_valid(void)
{
    return (wgen_read_status() & WGEN_STAT_VALID) != 0;
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

// Sequencer

void wgen_seq_set_len(unsigned len)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_SEQ_LEN, (uint32_t)len);
#else
    csr_write(WGEN_CSR_SEQ_LEN, (uint32_t)len);
#endif
}

void wgen_seq_set_ptr(unsigned ptr)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_SEQ_PTR, (uint32_t)ptr);
#else
    csr_write(WGEN_CSR_SEQ_PTR, (uint32_t)ptr);
#endif
}

void wgen_seq_write_data(uint32_t val)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_SEQ_DATA, val);
#else
    csr_write(WGEN_CSR_SEQ_DATA, val);
#endif
}

void wgen_seq_add_entry(unsigned i, const wgen_pulse_t *p)
{
    wgen_seq_set_ptr(i);
    wgen_seq_write_data(p->ftw);
    wgen_seq_write_data(p->pow);
    wgen_seq_write_data(p->amp);
    wgen_seq_write_data(p->env);
    wgen_seq_write_data(p->drag);
    wgen_seq_write_data(p->delay);
}

void wgen_seq_start(void)
{
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_SEQ_CTRL, 1);
#else
    csr_write(WGEN_CSR_SEQ_CTRL, 1);
#endif
}

int wgen_seq_is_busy(void)
{
    uint32_t s;
#ifdef WGEN_IF_MMIO
    s = wgen_read(WGEN_OFF_SEQ_CTRL);
#else
    s = csr_read(WGEN_CSR_SEQ_CTRL);
#endif
    return (s & WGEN_SEQ_BUSY) != 0;
}

int wgen_seq_is_done(void)
{
    uint32_t s;
#ifdef WGEN_IF_MMIO
    s = wgen_read(WGEN_OFF_SEQ_CTRL);
#else
    s = csr_read(WGEN_CSR_SEQ_CTRL);
#endif
    return (s & WGEN_SEQ_DONE) != 0;
}

void wgen_seq_wait_done(void)
{
    while (wgen_seq_is_busy());
}

void wgen_seq_run(unsigned len, unsigned repeat,
                  const wgen_pulse_t entries[])
{
    wgen_seq_set_len(len);
    for (unsigned i = 0; i < len; i++)
        wgen_seq_add_entry(i, &entries[i]);
#ifdef WGEN_IF_MMIO
    wgen_write(WGEN_OFF_SEQ_REPEAT, (uint32_t)repeat);
#else
    csr_write(WGEN_CSR_SEQ_REPEAT, (uint32_t)repeat);
#endif
    wgen_seq_start();
}
