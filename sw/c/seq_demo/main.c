#include "../common/leaf.h"
#include "../common/wgen.h"

static const wgen_pulse_t pulse1 = {
    .ftw   = 0x1999999A,
    .pow   = 0,
    .amp   = 0x000007FF,
    .env   = 0x0147AE14,
    .drag  = 0x00001999,
    .delay = 0,
};

static const wgen_pulse_t pulse2 = {
    .ftw   = 0x1999999A,
    .pow   = 0,
    .amp   = 0x00000400,
    .env   = 0x028F5C29,
    .drag  = 0x00001999,
    .delay = 0,
};

static const wgen_pulse_t pulse3 = {
    .ftw   = 0x33333333,
    .pow   = 0,
    .amp   = 0x00000C00,
    .env   = 0x0083126F,
    .drag  = 0,
    .delay = 0,
};

int main(void)
{
    const wgen_pulse_t seq[3] = { pulse1, pulse2, pulse3 };

    uart_puts("seq_demo\n");

    for (;;) {
        wgen_seq_run(3, 1, seq);
        wgen_seq_wait_done();
        uart_puts(".");
    }
}
