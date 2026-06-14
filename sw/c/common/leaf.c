#include "leaf.h"

#define SOC_CLOCK_HZ 50000000

static volatile uint8_t *const uart_stat = (volatile uint8_t *)(UART_BASE + UART_STAT);
static volatile uint8_t *const uart_data = (volatile uint8_t *)(UART_BASE + UART_DATA);
static volatile uint32_t *const uart_brdv = (volatile uint32_t *)(UART_BASE + UART_BRDV);

void uart_init(uint16_t baud_div)
{
    *uart_brdv = baud_div;
}

void uart_putchar(char c)
{
    while ((*uart_stat & UART_STAT_TX_READY) != UART_STAT_TX_READY);
    *uart_data = (uint8_t)c;
}

char uart_getchar(void)
{
    while ((*uart_stat & UART_STAT_RX_READY) != UART_STAT_RX_READY);
    return (char)(*uart_data);
}

void uart_puts(const char *str)
{
    while (*str)
        uart_putchar(*str++);
}

void uart_gets(char *str, int max_len)
{
    int i = 0;
    char c;
    while (i < max_len - 1)
    {
        c = uart_getchar();
        if (c == '\n' || c == '\r')
            break;
        str[i++] = c;
    }
    str[i] = '\0';
}

void uart_send_string(char *str)
{
    uart_puts(str);
}

void uart_receive_string(char *str)
{
    uart_gets(str, 256);
}

void uart_send_integer(int num)
{
    char str[20];
    itoa(num, str);
    uart_puts(str);
}

int uart_receive_integer(void)
{
    char str[20];
    uart_gets(str, sizeof(str));
    return atoi(str);
}

int uart_write(const char *buf, int len)
{
    for (int i = 0; i < len; i++)
        uart_putchar(buf[i]);
    return len;
}

uint64_t get_cycle(void)
{
    uint32_t lo, hi;
    __asm__ volatile("csrr %0, cycle\n\t"
                     "csrr %1, cycleh"
                     : "=r"(lo), "=r"(hi));
    return ((uint64_t)hi << 32) | lo;
}

void delay_cycles(uint32_t cycles)
{
    uint32_t start;
    __asm__ volatile("csrr %0, cycle" : "=r"(start));
    while (1)
    {
        uint32_t now;
        __asm__ volatile("csrr %0, cycle" : "=r"(now));
        if (now - start >= cycles)
            break;
    }
}

void delay_us(uint32_t us)
{
    delay_cycles(us * (SOC_CLOCK_HZ / 1000000));
}

void itoa(int num, char *str)
{
    int i = 0;
    int is_neg = 0;
    char tmp[20];

    if (num < 0)
    {
        is_neg = 1;
        num = -num;
    }

    if (num == 0)
    {
        str[i++] = '0';
        str[i] = '\0';
        return;
    }

    while (num != 0)
    {
        tmp[i++] = (num % 10) + '0';
        num /= 10;
    }

    if (is_neg)
        tmp[i++] = '-';

    for (int j = 0; j < i; j++)
        str[j] = tmp[i - 1 - j];
    str[i] = '\0';
}

int atoi(const char *str)
{
    int result = 0;
    int sign = 1;

    while (*str == ' ')
        str++;

    if (*str == '-')
    {
        sign = -1;
        str++;
    }
    else if (*str == '+')
    {
        str++;
    }

    while (*str >= '0' && *str <= '9')
    {
        result = result * 10 + (*str - '0');
        str++;
    }

    return result * sign;
}

void int2string(int num, char *str)
{
    itoa(num, str);
}

int string2int(char *str)
{
    return atoi(str);
}
