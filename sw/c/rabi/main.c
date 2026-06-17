#include "../common/leaf.h"
#include "../common/wgen.h"

#define FTW_PI   0x1999999A
#define ENV_PI   0x0147AE14
#define DRAG_PI  0x00001999

#define AMP_MIN     0
#define AMP_MAX     4095
#define AMP_STEP    41
#define AMP_POINTS ((AMP_MAX - AMP_MIN) / AMP_STEP + 1)

#define REPEAT 3

static void print_hex(uint32_t v)
{
    char buf[11];
    buf[0] = '0'; buf[1] = 'x';
    for (int i = 9; i >= 2; i--) {
        uint32_t nib = v & 0xF;
        buf[i] = nib < 10 ? '0' + nib : 'A' + nib - 10;
        v >>= 4;
    }
    buf[10] = '\0';
    uart_puts(buf);
}

int main(void)
{
    wgen_pulse_t p;

    uart_puts("rabi\n");

    p.ftw   = FTW_PI;
    p.pow   = 0;
    p.env   = ENV_PI;
    p.drag  = DRAG_PI;
    p.delay = 0;

    for (int r = 0; r < REPEAT; r++) {
        for (uint32_t amp = AMP_MIN; amp <= AMP_MAX; amp += AMP_STEP) {
            p.amp = (uint16_t)amp;
            wgen_pulse(&p);
            wgen_wait_ready();

            print_hex(amp);
            uart_puts("\n");
        }
    }

    uart_puts("done\n");
    for (;;);
}
