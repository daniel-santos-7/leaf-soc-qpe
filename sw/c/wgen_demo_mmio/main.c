#include "../common/leaf.h"
#include "../common/qpe_mmio.h"

#define FTW_PI        0x1999999A
#define AMP_PI        0x000007FF
#define ENV_PI        0x0147AE14
#define DRAG_PI       0x00001999

#define AMP_PI2       0x00000400
#define ENV_PI2       0x028F5C29

#define FTW_READOUT   0x33333333
#define AMP_READOUT   0x00000C00
#define ENV_READOUT   0x0083126F

static const qpe_mmio_pulse_t pi_pulse = {
    .ftw   = FTW_PI,
    .pow   = 0,
    .amp   = AMP_PI,
    .env   = ENV_PI,
    .drag  = DRAG_PI,
    .delay = 0,
};

static const qpe_mmio_pulse_t pi2_pulse = {
    .ftw   = FTW_PI,
    .pow   = 0,
    .amp   = AMP_PI2,
    .env   = ENV_PI2,
    .drag  = DRAG_PI,
    .delay = 0,
};

static const qpe_mmio_pulse_t readout_pulse = {
    .ftw   = FTW_READOUT,
    .pow   = 0,
    .amp   = AMP_READOUT,
    .env   = ENV_READOUT,
    .drag  = 0,
    .delay = 0,
};

int main(void)
{
    uart_puts("wgen_demo_mmio\n");
    qpe_mmio_init();

    for (;;) {
        qpe_mmio_pulse(&pi_pulse);
        qpe_mmio_wait_ready();
        uart_puts(".");

        qpe_mmio_pulse(&pi2_pulse);
        qpe_mmio_wait_ready();
        uart_puts(".");

        qpe_mmio_pulse(&readout_pulse);
        qpe_mmio_wait_ready();
        uart_puts(".");
    }
}
