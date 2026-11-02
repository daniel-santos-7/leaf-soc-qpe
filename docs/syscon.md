# System Controller
`wb_syscon` passes the clock through and generates two resets from the active-low `rst_n` pin:

- **`sys_rst_o`**, the system reset: `rst_n` through a three-flip-flop synchroniser. It asserts asynchronously, with or without a clock, and releases on the third rising edge of `clk` after `rst_n` rises.
- **`cpu_rst_o`**, the CPU reset: the same, and also held while the debug bridge's `HALT` is set. It comes from a flip-flop, so the CPU enters and leaves a halt one cycle after `HALT` changes.

Every other register resets synchronously, so the clock must run while reset is held. Any pulse on `rst_n` resets the chip, so the pin must be filtered in the pad or on the board.
