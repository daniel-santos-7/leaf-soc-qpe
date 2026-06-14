#ifndef LEAF_H
#define LEAF_H

#include <stdint.h>

#define UART_BASE   0x10000000
#define UART_STAT   0x00
#define UART_DATA   0x0C
#define UART_CTRL   0x04
#define UART_BRDV   0x08

#define UART_STAT_TX_READY  (1 << 5)
#define UART_STAT_RX_READY  (1 << 2)

#define read_csr(addr) ({ uint32_t _v; __asm__("csrr %0, %1" : "=r"(_v) : "i"(addr)); _v; })
#define write_csr(addr, val) __asm__("csrw %0, %1" :: "i"(addr), "r"((uint32_t)(val)))

// UART
void uart_init(uint16_t baud_div);
void uart_putchar(char c);
char uart_getchar(void);
void uart_puts(const char *str);
void uart_gets(char *str, int max_len);
void uart_send_string(char *str);
void uart_receive_string(char *str);
void uart_send_integer(int num);
int uart_receive_integer(void);
int uart_write(const char *buf, int len);

// CSR / timing
uint64_t get_cycle(void);
void delay_cycles(uint32_t cycles);
void delay_us(uint32_t us);

// Utility
void itoa(int num, char *str);
int atoi(const char *str);
void int2string(int num, char *str);
int string2int(char *str);

#endif
