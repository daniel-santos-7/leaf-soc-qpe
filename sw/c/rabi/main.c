#include "../common/leaf.h"
#include "../common/wgen.h"

#define FTW_PI   0x1999999A
#define ENV_PI   0x0147AE14
#define DRAG_PI  0x00001999

#define AMP_MIN  0
#define AMP_MAX  4095
#define AMP_STEP 41

#define REPEAT 3

int main(void)
{
    wgen_write_ftw(FTW_PI);
    wgen_write_pow(0);
    wgen_write_env(ENV_PI);
    wgen_write_drag(DRAG_PI);
    wgen_write_delay(0);

    for (int r = 0; r < REPEAT; r++) {
        for (uint32_t amp = AMP_MIN; amp <= AMP_MAX; amp += AMP_STEP) {
            wgen_write_amp((uint16_t)amp);
            wgen_trigger();
            wgen_wait_ready();
        }
    }

    for (;;);
}
