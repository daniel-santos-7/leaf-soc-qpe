#include <stdio.h>
#include <stdint.h>

#define RAM1_BASE  0x90000000u
#define RAM1_SIZE  0x400u

static uint32_t code[2] __attribute__((section(".ram1")));

static uint32_t mix(uint32_t c, uint32_t v) {
	return ((c << 5) | (c >> 27)) + v;
}

int main(void) {
	volatile uint32_t *w = (volatile uint32_t *)RAM1_BASE;
	volatile uint16_t *h = (volatile uint16_t *)RAM1_BASE;
	volatile uint8_t  *b = (volatile uint8_t  *)RAM1_BASE;
	uint32_t i, v, sum = 0, err = 0;

	for (i = 0; i < RAM1_SIZE / 4; i++)
		w[i] = ((i << 24) | (i << 16) | (i << 8) | i) ^ 0x5A3C0F00u;
	for (i = 0; i < RAM1_SIZE / 4; i++) {
		v = w[i];
		if (v != (((i << 24) | (i << 16) | (i << 8) | i) ^ 0x5A3C0F00u))
			err++;
		sum = mix(sum, v);
	}

	for (i = 0; i < RAM1_SIZE / 2; i++)
		h[i] = (uint16_t)(i ^ 0xBEEFu);
	for (i = 0; i < RAM1_SIZE / 4; i++) {
		v = w[i];
		if (v != ((((2 * i + 1) ^ 0xBEEFu) << 16) | ((2 * i) ^ 0xBEEFu)))
			err++;
		sum = mix(sum, v);
	}

	for (i = 0; i < RAM1_SIZE; i++)
		b[i] = (uint8_t)(i ^ 0x5Au);
	for (i = 0; i < RAM1_SIZE / 2; i++) {
		v = h[i];
		if (v != ((((2 * i + 1) ^ 0x5Au) & 0xFFu) << 8 | (((2 * i) ^ 0x5Au) & 0xFFu)))
			err++;
		sum = mix(sum, v);
	}

	printf("RAM1 sum=%08lx err=%lu\n", (unsigned long)sum, (unsigned long)err);

	code[0] = 0x02a00513u;
	code[1] = 0x00008067u;
	printf("RAM1 exec=%d\n", ((int (*)(void))code)());

	return 0;
}
