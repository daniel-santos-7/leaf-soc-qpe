#ifndef WGENGEN_H
#define WGENGEN_H

#include <stdint.h>

#define WGEN_CSR_FTW   0x7C0
#define WGEN_CSR_POW   0x7C1
#define WGEN_CSR_AMP   0x7C2
#define WGEN_CSR_ENV   0x7C3
#define WGEN_CSR_DELAY 0x7C4
#define WGEN_CSR_TRIG  0x7C5
#define WGEN_CSR_CTRL  0x7C6

#define WGEN_BASE      0x10001000
#define WGEN_OFF_FTW   0x00
#define WGEN_OFF_POW   0x04
#define WGEN_OFF_AMP   0x08
#define WGEN_OFF_ENV   0x0C
#define WGEN_OFF_DELAY 0x10
#define WGEN_OFF_TRIG  0x14
#define WGEN_OFF_CTRL  0x18

typedef struct {
    uint32_t ftw;
    uint32_t pow;
    uint16_t amp;
    uint32_t env;
    uint16_t drag;
    uint32_t delay;
} wgen_pulse_t;

void wgen_write_ftw(uint32_t val);
void wgen_write_pow(uint32_t val);
void wgen_write_amp(uint16_t val);
void wgen_write_env(uint32_t val);
void wgen_write_drag(uint16_t val);
void wgen_write_delay(uint32_t val);

uint32_t wgen_read_ftw(void);
uint32_t wgen_read_pow(void);
uint16_t wgen_read_amp(void);
uint32_t wgen_read_env(void);
uint16_t wgen_read_drag(void);
uint32_t wgen_read_delay(void);
void wgen_trigger(void);
int  wgen_is_ready(void);
int  wgen_is_valid(void);
void wgen_wait_ready(void);

void wgen_configure(const wgen_pulse_t *p);
void wgen_pulse(const wgen_pulse_t *p);

#endif
