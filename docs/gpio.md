# GPIO
The GPIO is the [`wb-gpio`](https://github.com/daniel-santos-7/wb-gpio) IP (submodule `ips/gpio`), 8 pins (`GPIO_WIDTH` in `leaf_soc_pkg`) on IO2, reached by the data master only.

| Offset | Register | Access | Description |
|--------|----------|--------|-------------|
| `0x00` | DATA_IN    | RO    | Synchronised pin values (2 flip-flops) |
| `0x04` | DATA_OUT   | RW    | Value driven on output pins |
| `0x08` | DIR        | RW    | 1 = output, 0 = input |
| `0x0C` | SET        | WO    | `DATA_OUT \|= wdata` |
| `0x10` | CLR        | WO    | `DATA_OUT &= ~wdata` |
| `0x14` | TGL        | WO    | `DATA_OUT ^= wdata` |
| `0x18` | IRQ_RISE   | RW    | Rising-edge interrupt enable |
| `0x1C` | IRQ_FALL   | RW    | Falling-edge interrupt enable |
| `0x20` | IRQ_STATUS | R/W1C | Pending events; writing 1 clears |

The pins leave `leaf_soc` as `gpio_i`, `gpio_o` and `gpio_oe` (1 = drive); the tri-state buffer belongs to the pads or the board. `irq_o` drives the CPU's external interrupt (`mip.MEIP`), the only interrupt source in the SoC. It stays high while any `IRQ_STATUS` bit is set, so a handler must clear the status before returning, and software must install its own `mtvec` handler to take it.

Software: `sw/c/common/gpio.c`/`gpio.h` in C (added through `APP_SRC`) and `sw/asm/common/gpio.inc` in assembly, with one call per register and pin masks as arguments. The assembly macros use `t6` for the base. `sw/c/gpio_test` shows the full flow, interrupt included.
