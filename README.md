# :leaves: Leaf

Leaf é um ecossistema SoC (*System-on-Chip*) baseado em um processador RISC-V de 32 bits, projetado para ser compacto, eficiente e ideal para aplicações em sistemas embarcados e IoT (Internet das Coisas).

## :star: Recursos

O núcleo Leaf possui as seguintes características:

- **ISA RISC-V (RV32I):** Suporte completo à extensão base de inteiros.
- **Pipeline de 2 estágios:** Otimizado para balanço entre área e frequência (Busca / Execução).
- **Interface Wishbone B4:** Master interface compatível com o padrão Wishbone para fácil integração de periféricos.
- **Suporte a CSRs (Machine Mode):** Implementação de registradores de controle e status (`mtvec`, `mepc`, `mcause`, `mstatus`, `mie`, `mip`, `mscratch`, `mtval`) e contadores (`mcycle`, `minstret`, `mtime`).
- **Tratamento de Interrupções:** Suporte a interrupções externas, de software e de timer.
- **Coprocessador Interface:** Janela de CSRs customizada (0x7C0-0x7FF) para expansão de hardware.

## :file_folder: Estrutura do Projeto

O repositório está organizado da seguinte forma:

Diretório             | Descrição
--------------------- | ---------------------------------------------------------
[`ips/cpu/`](ips/cpu/) | Núcleo do processador Leaf (Submódulo)
[`ips/uart/`](ips/uart/) | Periférico UART com interface Wishbone Slave (Submódulo)
[`ips/wgen/`](ips/wgen/) | Gerador de sinais senoidais via DDS (Submódulo)
[`soc/`](soc/)         | RTL e testbenches do SoC completo (FPGA-sintetizável)
[`sw/`](sw/)           | Programas de teste e bibliotecas (C e Assembly)

## :rocket: Como Começar

### Pré-requisitos

Para simular e desenvolver para o Leaf, você precisará de:

- **GHDL:** Simulador VHDL open-source.
- **Toolchain RISC-V:** `riscv32-unknown-elf-gcc` (configurada para `rv32i`).
- **GNU Make:** Automação de builds.
- **GTKWave:** Visualizador de formas de onda (opcional).

### Configuração Inicial

Como os IPs são gerenciados via submódulos Git, inicialize-os após clonar o repositório:

```bash
git submodule update --init --recursive
```

### Simulação do SoC

O projeto inclui um Makefile na raiz para facilitar a simulação do sistema completo.

1. **Compilar um programa (exemplo em C):**
   ```bash
   make -C sw/c/hello_world
   ```

2. **Executar a simulação:**
   ```bash
   make run PROGRAM=sw/c/hello_world/hello_world.bin
   ```

As formas de onda serão geradas no diretório `waves/` e podem ser visualizadas com o GTKWave:
```bash
gtkwave waves/hello_world.ghw
```

## :computer: Ambiente de Desenvolvimento

Em sistemas baseados em Linux (Debian/Ubuntu), você pode instalar as ferramentas de simulação com:

```bash
sudo apt install ghdl gtkwave make
```

---

<p align="center">2026</p>
