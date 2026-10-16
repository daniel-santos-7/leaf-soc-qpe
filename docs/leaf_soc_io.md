# IOs do `leaf_soc`

Portas da entidade `leaf_soc` (`soc/rtl/leaf_soc.vhdl`), com `OUT_RES_BITS = 10` e `GPIO_WIDTH = 8`.

| Grupo | Porta | Dir. | Bits | Função |
|---|---|---|---|---|
| Sistema | `clk` | in | 1 | clock do sistema |
| | `rst_n` | in | 1 | reset, ativo em baixo (sincronizado no `wb_syscon`) |
| UART | `rx` | in | 1 | recepção serial |
| | `tx` | out | 1 | transmissão serial |
| Pulsos (QPE) | `sig_i` | out | 10 | amostra I (do gerador, ou `dac_dat` com `dac_sel = 1`) |
| | `sig_q` | out | 10 | amostra Q (idem) |
| | `active` | out | 1 | gerador emitindo um pulso |
| Entrada externa do DAC | `dac_dat` | in | 10 | valor posto em `sig_i` e `sig_q` com `dac_sel = 1` |
| | `dac_sel` | in | 1 | 1 = `dac_dat` nas saídas, 0 = amostras do QPE |
| SPI (XIP / debug) | `sclk_i` | in | 1 | SCK vindo do host de debug (papel slave) |
| | `sclk_o` | out | 1 | SCK gerado pelo SoC (papel master, XIP) |
| | `sclk_oe` | out | 1 | 1 = o SoC dirige o SCK (master) |
| | `cs_n_i` | in | 1 | `CS#` vindo do host de debug (slave) |
| | `cs_n_o` | out | 1 | `CS#` gerado pelo SoC para a flash (master) |
| | `cs_n_oe` | out | 1 | 1 = o SoC dirige o `CS#`; a placa usa para ligar a flash |
| | `mosi_i` | in | 1 | MOSI vindo do host de debug (slave) |
| | `mosi_o` | out | 1 | MOSI gerado pelo SoC para a flash (master) |
| | `mosi_oe` | out | 1 | 1 = o SoC dirige o MOSI (master) |
| | `miso_i` | in | 1 | MISO vindo da flash (master) |
| | `miso_o` | out | 1 | MISO gerado pelo SoC para o host (slave) |
| | `miso_oe` | out | 1 | 1 = o SoC dirige o MISO (slave, só com `CS#` baixo) |
| GPIO | `gpio_i` | in | 8 | valor lido dos pinos |
| | `gpio_o` | out | 8 | valor escrito nos pinos |
| | `gpio_oe` | out | 8 | habilitação de saída, por bit |

## Totais

- Sinais de porta: 26 bits de entrada e 47 de saída, 73 no total.
- Pads físicos, contando cada trio `_i`/`_o`/`_oe` como um pad bidirecional: 4 de sistema e UART, 21 de pulsos, 11 do DAC externo, 4 de SPI e 8 de GPIO, 48 pads no total.

Não há tri-state dentro do SoC: os pinos de SPI e GPIO saem separados em `_i`/`_o`/`_oe`, e os pads ou a placa fazem a resolução. O papel da porta SPI (master para a flash ou slave para o debug) vem do bit `EN` do registrador de configuração do XIP, em `0x20FFFFFC`.
