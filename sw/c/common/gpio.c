#include "gpio.h"

#define GPIO_REG(off) (*(volatile uint32_t *)(GPIO_BASE + (off)))

void gpio_set_dir(uint32_t mask)
{
    GPIO_REG(GPIO_OFF_DIR) = mask;
}

uint32_t gpio_get_dir(void)
{
    return GPIO_REG(GPIO_OFF_DIR);
}

uint32_t gpio_get_in(void)
{
    return GPIO_REG(GPIO_OFF_DATA_IN);
}

void gpio_set_out(uint32_t val)
{
    GPIO_REG(GPIO_OFF_DATA_OUT) = val;
}

uint32_t gpio_get_out(void)
{
    return GPIO_REG(GPIO_OFF_DATA_OUT);
}

void gpio_set_bits(uint32_t mask)
{
    GPIO_REG(GPIO_OFF_SET) = mask;
}

void gpio_clr_bits(uint32_t mask)
{
    GPIO_REG(GPIO_OFF_CLR) = mask;
}

void gpio_tgl_bits(uint32_t mask)
{
    GPIO_REG(GPIO_OFF_TGL) = mask;
}

void gpio_set_irq_rise(uint32_t mask)
{
    GPIO_REG(GPIO_OFF_IRQ_RISE) = mask;
}

uint32_t gpio_get_irq_rise(void)
{
    return GPIO_REG(GPIO_OFF_IRQ_RISE);
}

void gpio_set_irq_fall(uint32_t mask)
{
    GPIO_REG(GPIO_OFF_IRQ_FALL) = mask;
}

uint32_t gpio_get_irq_fall(void)
{
    return GPIO_REG(GPIO_OFF_IRQ_FALL);
}

uint32_t gpio_get_irq_status(void)
{
    return GPIO_REG(GPIO_OFF_IRQ_STATUS);
}

void gpio_clr_irq_status(uint32_t mask)
{
    GPIO_REG(GPIO_OFF_IRQ_STATUS) = mask;
}
