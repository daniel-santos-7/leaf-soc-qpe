#include <stdio.h>
#include <stdint.h>
#include <errno.h>
#include <sys/stat.h>

#undef errno
extern int errno;

#define UART_BASE   0x10000000
#define UART_STAT   0x00  // Status: bit2=RX ready, bit5=TX ready
#define UART_DATA   0x0C  // TX/RX data register

volatile uint32_t *uart_stat = (volatile uint32_t *)(UART_BASE + UART_STAT);
volatile uint32_t *uart_data = (volatile uint32_t *)(UART_BASE + UART_DATA);

void _exit(int n) {
  for (;;);
}

int _close(int file) {
  return -1;
}

char *__env[1] = { 0 };
char **environ = __env;

int _execve(char *name, char **argv, char **env) {
  errno = ENOMEM;
  return -1;
}

int _fork(void) {
  errno = EAGAIN;
  return -1;
}

int _fstat(int file, struct stat *st) {
  st->st_mode = S_IFCHR;
  return 0;
}

int _getpid(void) {
  return 1;
}

int _isatty(int file) {
  return 1;
}

int _kill(int pid, int sig) {
  errno = EINVAL;
  return -1;
}

int _link(char *old, char *new) {
  errno = EMLINK;
  return -1;
}

int _lseek(int file, int ptr, int dir) {
  return 0;
}

int _open(const char *name, int flags, int mode) {
  return -1;
}

int _read(int file, char *ptr, int len) {
  int i;
  for (i = 0; i < len; i++) {
    while ((*uart_stat & 0x4) != 0x4);
    ptr[i] = (char)*uart_data;
    if (ptr[i] == '\n') return i+1;
  }

  return i;
}

char *_sbrk(int incr) {
  extern char __end;
  static char *heap_end;
  char *prev_heap_end;

  if (heap_end == 0) {
    heap_end = &__end;
  }
  prev_heap_end = heap_end;

  heap_end += incr;
  return prev_heap_end;
}

int _stat(char *file, struct stat *st) {
  st->st_mode = S_IFCHR;
  return 0;
}

int _times(struct tms *buf) {
  return -1;
}

int _unlink(char *name) {
  errno = ENOENT;
  return -1; 
}

int _wait(int *status) {
  errno = ECHILD;
  return -1;
}

int _write(int file, char *ptr, int len) {
  if ((file != 1) && (file != 2) && (file != 3)) {
    return -1;
  }

  int todo;
  for(todo = 0; todo < len; todo++) {
    while ((*uart_stat & 0x20) != 0x20);
    *uart_data = (uint32_t)*ptr++;
  }

  return len;
}