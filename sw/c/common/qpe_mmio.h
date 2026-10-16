#ifndef QPE_MMIO_H
#define QPE_MMIO_H

#include <stdint.h>

#define QPE_MMIO_BASE        0x10001000
#define QPE_MMIO_OFF_FTW     0x00
#define QPE_MMIO_OFF_POW     0x04
#define QPE_MMIO_OFF_AMP     0x08
#define QPE_MMIO_OFF_DRAG    0x0C
#define QPE_MMIO_OFF_ENV     0x10
#define QPE_MMIO_OFF_DELAY   0x14
#define QPE_MMIO_OFF_TRIG    0x18
#define QPE_MMIO_OFF_CTRL    0x1C

typedef struct {
    uint32_t ftw;
    uint32_t pow;
    uint16_t amp;
    uint32_t env;
    uint16_t drag;
    uint32_t delay;
} qpe_mmio_pulse_t;

void qpe_mmio_set_ftw(uint32_t val);
void qpe_mmio_set_pow(uint32_t val);
void qpe_mmio_set_amp(uint16_t val);
void qpe_mmio_set_env(uint32_t val);
void qpe_mmio_set_drag(uint16_t val);
void qpe_mmio_set_delay(uint32_t val);

uint32_t qpe_mmio_get_ftw(void);
uint32_t qpe_mmio_get_pow(void);
uint16_t qpe_mmio_get_amp(void);
uint32_t qpe_mmio_get_env(void);
uint16_t qpe_mmio_get_drag(void);
uint32_t qpe_mmio_get_delay(void);

void qpe_mmio_trigger(void);
int  qpe_mmio_is_ready(void);
int  qpe_mmio_is_valid(void);
void qpe_mmio_wait_ready(void);

void qpe_mmio_init(void);

void qpe_mmio_configure(const qpe_mmio_pulse_t *p);
void qpe_mmio_pulse(const qpe_mmio_pulse_t *p);

#endif
