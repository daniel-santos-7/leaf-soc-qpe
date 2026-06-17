#include "../common/leaf.h"
#include "../common/wgen.h"

#define FTW_PI       0x1999999A
#define DRAG_PI      0x00001999

#define AMP_PI2      0x00000400
#define ENV_PI2      0x028F5C29

#define FTW_READOUT  0x33333333
#define AMP_READOUT  0x00000C00
#define ENV_READOUT  0x0083126F

#define DELAY_MIN_US     0
#define DELAY_MAX_US     50
#define DELAY_STEP_US    2
#define DELAY_POINTS     ((DELAY_MAX_US - DELAY_MIN_US) / DELAY_STEP_US + 1)

#define REPEAT 3

static const wgen_pulse_t pi2_pulse = {
    .ftw   = FTW_PI,
    .pow   = 0,
    .amp   = AMP_PI2,
    .env   = ENV_PI2,
    .drag  = DRAG_PI,
    .delay = 0,
};

static const wgen_pulse_t readout_pulse = {
    .ftw   = FTW_READOUT,
    .pow   = 0,
    .amp   = AMP_READOUT,
    .env   = ENV_READOUT,
    .drag  = 0,
    .delay = 0,
};

static void print_dec(uint32_t v)
{
    char buf[12];
    int i = 0;
    if (v == 0) { buf[i++] = '0'; }
    else {
        char tmp[12];
        int j = 0;
        while (v) { tmp[j++] = '0' + (v % 10); v /= 10; }
        while (j) { buf[i++] = tmp[--j]; }
    }
    buf[i] = '\0';
    uart_puts(buf);
}

int main(void)
{
    uart_puts("ramsey\n");

    for (int r = 0; r < REPEAT; r++) {
        for (uint32_t delay = DELAY_MIN_US; delay <= DELAY_MAX_US; delay += DELAY_STEP_US) {
            wgen_pulse(&pi2_pulse);
            wgen_wait_ready();

            if (delay > 0)
                delay_us(delay);

            wgen_pulse(&pi2_pulse);
            wgen_wait_ready();

            wgen_pulse(&readout_pulse);
            wgen_wait_ready();

            print_dec(delay);
            uart_puts("\n");
        }
    }

    uart_puts("done\n");
    for (;;);
}
