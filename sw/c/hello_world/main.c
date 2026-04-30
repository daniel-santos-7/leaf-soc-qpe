#include <stdio.h>

int main(void) {
	const char * volatile fmt = "%s";

	printf(fmt, "Hello World!\nLeaf is working.\n");
	fflush(stdout);

	for (;;);
}
