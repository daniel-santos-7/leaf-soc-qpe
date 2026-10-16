#include "../common/leaf.h"
#include "../common/qpe.h"

#define FTW_PI   0x1999999A
#define ENV_PI   0x0147AE14
#define DRAG_PI  0x00001999

#define AMP_MIN  0
#define AMP_MAX  4095
#define AMP_STEP 41

#define REPEAT 3

int main(void)
{
    qpe_init();
    qpe_set_ftw(FTW_PI);
    qpe_set_pow(0);
    qpe_set_env(ENV_PI);
    qpe_set_drag(DRAG_PI);
    qpe_set_delay(0);

    for (int r = 0; r < REPEAT; r++) {
        for (uint32_t amp = AMP_MIN; amp <= AMP_MAX; amp += AMP_STEP) {
            qpe_set_amp((uint16_t)amp);
            qpe_trigger();
            qpe_wait_ready();
        }
    }

    for (;;);
}
