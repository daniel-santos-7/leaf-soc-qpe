#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

#define GPIO_BASE           0x10002000
#define GPIO_OFF_DATA_IN    0x00
#define GPIO_OFF_DATA_OUT   0x04
#define GPIO_OFF_DIR        0x08
#define GPIO_OFF_SET        0x0C
#define GPIO_OFF_CLR        0x10
#define GPIO_OFF_TGL        0x14
#define GPIO_OFF_IRQ_RISE   0x18
#define GPIO_OFF_IRQ_FALL   0x1C
#define GPIO_OFF_IRQ_STATUS 0x20

void     gpio_set_dir(uint32_t mask);
uint32_t gpio_get_dir(void);

uint32_t gpio_get_in(void);
void     gpio_set_out(uint32_t val);
uint32_t gpio_get_out(void);

void gpio_set_bits(uint32_t mask);
void gpio_clr_bits(uint32_t mask);
void gpio_tgl_bits(uint32_t mask);

void     gpio_set_irq_rise(uint32_t mask);
uint32_t gpio_get_irq_rise(void);
void     gpio_set_irq_fall(uint32_t mask);
uint32_t gpio_get_irq_fall(void);
uint32_t gpio_get_irq_status(void);
void     gpio_clr_irq_status(uint32_t mask);

#endif
