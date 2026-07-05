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
    *(volatile uint16_t *)((uintptr_t)wgen + WGEN_OFF_AMP) = val;
#else
    csr_write(WGEN_CSR_AMP, val);
#endif
}

void wgen_write_drag(uint16_t val)
{
#ifdef WGEN_IF_MMIO
    *(volatile uint16_t *)((uintptr_t)wgen + WGEN_OFF_DRAG) = val;
#else
    csr_write(WGEN_CSR_DRAG, val);
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
    return (wgen_read_status() & (1u << 1)) != 0;
}

int wgen_is_valid(void)
{
    return (wgen_read_status() & (1u << 0)) != 0;
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

// --- Bank-aware functions (COP mode sequencer) ---

#ifndef WGEN_IF_MMIO

// RISC-V CSR instructions require a compile-time constant address.
// Use switch-based helpers to map (bank, reg) to fixed CSR addresses.
// Banks 0..11, each with 5 registers (FTW, POW, AMP+drag, ENV, DELAY)
// CSR base = 0x7C0, stride = 5.

static void wgen_bank_write_reg(int bank, int reg, uint32_t val)
{
    switch (bank * 5 + reg) {
        case  0: csr_write(0x7C0, val); break;
        case  1: csr_write(0x7C1, val); break;
        case  2: csr_write(0x7C2, val); break;
        case  3: csr_write(0x7C3, val); break;
        case  4: csr_write(0x7C4, val); break;
        case  5: csr_write(0x7C5, val); break;
        case  6: csr_write(0x7C6, val); break;
        case  7: csr_write(0x7C7, val); break;
        case  8: csr_write(0x7C8, val); break;
        case  9: csr_write(0x7C9, val); break;
        case 10: csr_write(0x7CA, val); break;
        case 11: csr_write(0x7CB, val); break;
        case 12: csr_write(0x7CC, val); break;
        case 13: csr_write(0x7CD, val); break;
        case 14: csr_write(0x7CE, val); break;
        case 15: csr_write(0x7CF, val); break;
        case 16: csr_write(0x7D0, val); break;
        case 17: csr_write(0x7D1, val); break;
        case 18: csr_write(0x7D2, val); break;
        case 19: csr_write(0x7D3, val); break;
        case 20: csr_write(0x7D4, val); break;
        case 21: csr_write(0x7D5, val); break;
        case 22: csr_write(0x7D6, val); break;
        case 23: csr_write(0x7D7, val); break;
        case 24: csr_write(0x7D8, val); break;
        case 25: csr_write(0x7D9, val); break;
        case 26: csr_write(0x7DA, val); break;
        case 27: csr_write(0x7DB, val); break;
        case 28: csr_write(0x7DC, val); break;
        case 29: csr_write(0x7DD, val); break;
        case 30: csr_write(0x7DE, val); break;
        case 31: csr_write(0x7DF, val); break;
        case 32: csr_write(0x7E0, val); break;
        case 33: csr_write(0x7E1, val); break;
        case 34: csr_write(0x7E2, val); break;
        case 35: csr_write(0x7E3, val); break;
        case 36: csr_write(0x7E4, val); break;
        case 37: csr_write(0x7E5, val); break;
        case 38: csr_write(0x7E6, val); break;
        case 39: csr_write(0x7E7, val); break;
        case 40: csr_write(0x7E8, val); break;
        case 41: csr_write(0x7E9, val); break;
        case 42: csr_write(0x7EA, val); break;
        case 43: csr_write(0x7EB, val); break;
        case 44: csr_write(0x7EC, val); break;
        case 45: csr_write(0x7ED, val); break;
        case 46: csr_write(0x7EE, val); break;
        case 47: csr_write(0x7EF, val); break;
        case 48: csr_write(0x7F0, val); break;
        case 49: csr_write(0x7F1, val); break;
        case 50: csr_write(0x7F2, val); break;
        case 51: csr_write(0x7F3, val); break;
        case 52: csr_write(0x7F4, val); break;
        case 53: csr_write(0x7F5, val); break;
        case 54: csr_write(0x7F6, val); break;
        case 55: csr_write(0x7F7, val); break;
        case 56: csr_write(0x7F8, val); break;
        case 57: csr_write(0x7F9, val); break;
        case 58: csr_write(0x7FA, val); break;
        case 59: csr_write(0x7FB, val); break;
    }
}

static uint32_t wgen_bank_read_reg(int bank, int reg)
{
    switch (bank * 5 + reg) {
        case  0: return csr_read(0x7C0);
        case  1: return csr_read(0x7C1);
        case  2: return csr_read(0x7C2);
        case  3: return csr_read(0x7C3);
        case  4: return csr_read(0x7C4);
        case  5: return csr_read(0x7C5);
        case  6: return csr_read(0x7C6);
        case  7: return csr_read(0x7C7);
        case  8: return csr_read(0x7C8);
        case  9: return csr_read(0x7C9);
        case 10: return csr_read(0x7CA);
        case 11: return csr_read(0x7CB);
        case 12: return csr_read(0x7CC);
        case 13: return csr_read(0x7CD);
        case 14: return csr_read(0x7CE);
        case 15: return csr_read(0x7CF);
        case 16: return csr_read(0x7D0);
        case 17: return csr_read(0x7D1);
        case 18: return csr_read(0x7D2);
        case 19: return csr_read(0x7D3);
        case 20: return csr_read(0x7D4);
        case 21: return csr_read(0x7D5);
        case 22: return csr_read(0x7D6);
        case 23: return csr_read(0x7D7);
        case 24: return csr_read(0x7D8);
        case 25: return csr_read(0x7D9);
        case 26: return csr_read(0x7DA);
        case 27: return csr_read(0x7DB);
        case 28: return csr_read(0x7DC);
        case 29: return csr_read(0x7DD);
        case 30: return csr_read(0x7DE);
        case 31: return csr_read(0x7DF);
        case 32: return csr_read(0x7E0);
        case 33: return csr_read(0x7E1);
        case 34: return csr_read(0x7E2);
        case 35: return csr_read(0x7E3);
        case 36: return csr_read(0x7E4);
        case 37: return csr_read(0x7E5);
        case 38: return csr_read(0x7E6);
        case 39: return csr_read(0x7E7);
        case 40: return csr_read(0x7E8);
        case 41: return csr_read(0x7E9);
        case 42: return csr_read(0x7EA);
        case 43: return csr_read(0x7EB);
        case 44: return csr_read(0x7EC);
        case 45: return csr_read(0x7ED);
        case 46: return csr_read(0x7EE);
        case 47: return csr_read(0x7EF);
        case 48: return csr_read(0x7F0);
        case 49: return csr_read(0x7F1);
        case 50: return csr_read(0x7F2);
        case 51: return csr_read(0x7F3);
        case 52: return csr_read(0x7F4);
        case 53: return csr_read(0x7F5);
        case 54: return csr_read(0x7F6);
        case 55: return csr_read(0x7F7);
        case 56: return csr_read(0x7F8);
        case 57: return csr_read(0x7F9);
        case 58: return csr_read(0x7FA);
        case 59: return csr_read(0x7FB);
        default: return 0;
    }
}

#define CSR_WGEN_RUN 0x7FF

void wgen_bank_write_ftw(int bank, uint32_t val)
{
    wgen_bank_write_reg(bank, 0, val);
}

void wgen_bank_write_pow(int bank, uint32_t val)
{
    wgen_bank_write_reg(bank, 1, val);
}

void wgen_bank_write_amp(int bank, uint16_t val)
{
    uint32_t tmp = wgen_bank_read_reg(bank, 2) & 0xFFFF0000;
    wgen_bank_write_reg(bank, 2, tmp | val);
}

void wgen_bank_write_drag(int bank, uint16_t val)
{
    uint32_t tmp = wgen_bank_read_reg(bank, 2) & 0x0000FFFF;
    wgen_bank_write_reg(bank, 2, tmp | ((uint32_t)val << 16));
}

void wgen_bank_write_env(int bank, uint32_t val)
{
    wgen_bank_write_reg(bank, 3, val);
}

void wgen_bank_write_delay(int bank, uint32_t val)
{
    wgen_bank_write_reg(bank, 4, val);
}

uint32_t wgen_bank_read_ftw(int bank)
{
    return wgen_bank_read_reg(bank, 0);
}

uint32_t wgen_bank_read_pow(int bank)
{
    return wgen_bank_read_reg(bank, 1);
}

uint16_t wgen_bank_read_amp(int bank)
{
    return (uint16_t)wgen_bank_read_reg(bank, 2);
}

uint16_t wgen_bank_read_drag(int bank)
{
    return (uint16_t)(wgen_bank_read_reg(bank, 2) >> 16);
}

uint32_t wgen_bank_read_env(int bank)
{
    return wgen_bank_read_reg(bank, 3);
}

uint32_t wgen_bank_read_delay(int bank)
{
    return wgen_bank_read_reg(bank, 4);
}

void wgen_bank_configure(int bank, const wgen_pulse_t *p)
{
    wgen_bank_write_reg(bank, 0, p->ftw);
    wgen_bank_write_reg(bank, 1, p->pow);
    wgen_bank_write_reg(bank, 2, ((uint32_t)p->drag << 16) | p->amp);
    wgen_bank_write_reg(bank, 3, p->env);
    wgen_bank_write_reg(bank, 4, p->delay);
}

void wgen_seq_run(int count)
{
    csr_write(CSR_WGEN_RUN, ((count & 0xF) << 4) | 1);
}

int wgen_seq_is_active(void)
{
    return csr_read(CSR_WGEN_RUN) & 1;
}

void wgen_seq_wait_done(void)
{
    while (wgen_seq_is_active());
}

#else

void wgen_bank_write_ftw(int bank, uint32_t val) { (void)bank; wgen_write_ftw(val); }
void wgen_bank_write_pow(int bank, uint32_t val) { (void)bank; wgen_write_pow(val); }
void wgen_bank_write_amp(int bank, uint16_t val) { (void)bank; wgen_write_amp(val); }
void wgen_bank_write_drag(int bank, uint16_t val) { (void)bank; wgen_write_drag(val); }
void wgen_bank_write_env(int bank, uint32_t val) { (void)bank; wgen_write_env(val); }
void wgen_bank_write_delay(int bank, uint32_t val) { (void)bank; wgen_write_delay(val); }

uint32_t wgen_bank_read_ftw(int bank) { (void)bank; return wgen_read_ftw(); }
uint32_t wgen_bank_read_pow(int bank) { (void)bank; return wgen_read_pow(); }
uint16_t wgen_bank_read_amp(int bank) { (void)bank; return wgen_read_amp(); }
uint16_t wgen_bank_read_drag(int bank) { (void)bank; return wgen_read_drag(); }
uint32_t wgen_bank_read_env(int bank) { (void)bank; return wgen_read_env(); }
uint32_t wgen_bank_read_delay(int bank) { (void)bank; return wgen_read_delay(); }

void wgen_bank_configure(int bank, const wgen_pulse_t *p) { (void)bank; wgen_configure(p); }
void wgen_seq_run(int count) { (void)count; wgen_trigger(); }
int  wgen_seq_is_active(void) { return 0; }
void wgen_seq_wait_done(void) { wgen_wait_ready(); }

#endif


