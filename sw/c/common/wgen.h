#ifndef WGENGEN_H
#define WGENGEN_H

#include <stdint.h>

#define WGEN_CSR_FTW   0x7C0
#define WGEN_CSR_POW   0x7C1
#define WGEN_CSR_AMP   0x7C2
#define WGEN_CSR_ENV   0x7C3
#define WGEN_CSR_DRAG  0x7C4
#define WGEN_CSR_DELAY 0x7C5
#define WGEN_CSR_STAT  0x7C6

#define WGEN_BASE      0x10001000
#define WGEN_OFF_FTW   0x00
#define WGEN_OFF_POW   0x04
#define WGEN_OFF_AMP   0x08
#define WGEN_OFF_ENV   0x0C
#define WGEN_OFF_DRAG  0x10
#define WGEN_OFF_DELAY 0x14
#define WGEN_OFF_STAT  0x18

#define WGEN_CSR_SEQ_LEN    0x7C7
#define WGEN_CSR_SEQ_PTR    0x7C8
#define WGEN_CSR_SEQ_DATA   0x7C9
#define WGEN_CSR_SEQ_CTRL   0x7CA
#define WGEN_CSR_SEQ_REPEAT 0x7CB

#define WGEN_OFF_SEQ_LEN     0x1C
#define WGEN_OFF_SEQ_PTR     0x20
#define WGEN_OFF_SEQ_DATA    0x24
#define WGEN_OFF_SEQ_CTRL    0x28
#define WGEN_OFF_SEQ_REPEAT  0x2C

#define WGEN_STAT_VALID (1u << 0)
#define WGEN_STAT_READY (1u << 1)

#define WGEN_SEQ_BUSY   (1u << 0)
#define WGEN_SEQ_DONE   (1u << 1)

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

// Sequencer
void wgen_seq_set_len(unsigned len);
void wgen_seq_set_ptr(unsigned ptr);
void wgen_seq_write_data(uint32_t val);
void wgen_seq_add_entry(unsigned i, const wgen_pulse_t *p);
void wgen_seq_start(void);
int  wgen_seq_is_busy(void);
int  wgen_seq_is_done(void);
void wgen_seq_wait_done(void);
void wgen_seq_run(unsigned len, unsigned repeat,
                  const wgen_pulse_t entries[]);

#endif
