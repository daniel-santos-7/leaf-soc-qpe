#ifndef QPE_H
#define QPE_H

#include <stdint.h>

#define QPE_CSR_FTW   0x7C0
#define QPE_CSR_POW   0x7C1
#define QPE_CSR_AMP   0x7C2
#define QPE_CSR_DRAG  0x7C3
#define QPE_CSR_ENV   0x7C4
#define QPE_CSR_DELAY 0x7C5
#define QPE_CSR_TRIG  0x7C6

typedef struct {
    uint32_t ftw;
    uint32_t pow;
    uint16_t amp;
    uint32_t env;
    uint16_t drag;
    uint32_t delay;
} qpe_pulse_t;

void qpe_set_ftw(uint32_t val);
void qpe_set_pow(uint32_t val);
void qpe_set_amp(uint16_t val);
void qpe_set_env(uint32_t val);
void qpe_set_drag(uint16_t val);
void qpe_set_delay(uint32_t val);

void qpe_trigger(void);
int  qpe_is_ready(void);
void qpe_wait_ready(void);

void qpe_init(void);

void qpe_configure(const qpe_pulse_t *p);
void qpe_pulse(const qpe_pulse_t *p);

#endif
