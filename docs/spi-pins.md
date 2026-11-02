# SPI Pins
XIP and the debug bridge share one set of four SPI pins: the SoC is the master for XIP and a slave for debug. Both roles use one `spi_port` from the [`ips/spi`](../ips/spi/) IP, and `spi_mux` connects it to `wb_xip_ctrl` or `wb_dbg_ctrl` according to the role in effect. The `EN` bit of the XIP configuration register picks the role:

| `EN` | Role | SCK, `CS#`, MOSI | MISO |
|------|------|------------------|------|
| 1 | master (XIP) | driven by the SoC | input from the flash |
| 0 | slave (debug) | inputs from the debug host | driven by the SoC while `CS#` is low |

`EN` resets to 0, so after a reset the port belongs to the debug bridge and a host can always reach the SoC. The role changes only between frames. Each pin leaves `leaf_soc` as `_i`, `_o` and `_oe`; there is no tri-state inside the SoC.

`CS#` is shared too, so the board must pass it to the flash only while `cs_n_oe` is 1, and hold the flash deselected otherwise; if not, the flash decodes debug frames and fights the SoC on MISO. The testbench does the same, with a pull-down on MISO.
