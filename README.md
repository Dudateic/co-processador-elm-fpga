# Marco 1 — Co-processador ELM em FPGA

> **TEC 499 — MI Sistemas Digitais 2026.1 | UEFS**  
> Entrega: 15/04/2026

---

## Sumário

- [Objetivo](#objetivo)
- [Levantamento de Requisitos](#levantamento-de-requisitos)
- [Softwares Utilizados](#softwares-utilizados)
- [Hardware Utilizado](#hardware-utilizado)
- [Estrutura dos Arquivos](#estrutura-dos-arquivos)
- [Arquitetura do Co-processador](#arquitetura-do-co-processador)
- [Instalação e Configuração do Ambiente](#instalação-e-configuração-do-ambiente)
- [Como Simular](#como-simular)
- [Testes de Funcionamento](#testes-de-funcionamento)
- [Análise dos Resultados](#análise-dos-resultados)

---

## Objetivo

Construir e validar o IP de inferência ELM em RTL (Register Transfer Level), implementando um co-processador capaz de classificar dígitos manuscritos (MNIST 28×28 pixels) diretamente em FPGA, com aritmética em ponto fixo Q4.12.

---

## Levantamento de Requisitos

### Funcionais

- Inferência ELM completa: entrada 784 pixels → 128 neurônios ocultos → 10 classes de saída
- Ativação sigmoid piecewise linear (20 segmentos, erro máx. 1,49%)
- Argmax sequencial sobre os 10 valores de saída → predição `[0..9]`
- ISA de 5 instruções (32-bit): `STORE_IMG`, `STORE_WEIGHTS`, `STORE_BIAS`, `START`, `STATUS`
- Interface de disparo dupla: via ISA (host) e via chave física KEY1 (FPGA)
- Display 7 segmentos mostrando estado (`IdLE` / `bUSY` / `donE X`)

### Restrições de Memória

| Memória | Entradas | Uso real |
|---|---|---|
| Imagem (`imagem`) | 1.024 × 16-bit | 784 pixels |
| Pesos W_in (`peso`) | 131.072 × 16-bit | 100.352 (784 × 128) |
| Beta β (`beta`) | 2.048 × 16-bit | 1.280 (128 × 10) |
| Bias b (`bias`) | 128 × 16-bit | 128 |

---

## Softwares Utilizados

| Software | Versão | Finalidade |
|---|---|---|
| Intel Quartus Prime Lite | 18.1 | Síntese, place & route, programação FPGA |
| ModelSim-Intel FPGA Starter | 10.5b | Simulação RTL |
|Icarus Verilog| | 
| Python | 3.10+ | Golden model, geração de vetores de teste |
| NumPy | 1.24+ | Operações matriciais do modelo ELM de referência |
| Git | 2.x | Controle de versão |

---

## Hardware Utilizado

- **Placa:** DE1-SoC — Terasic
  - FPGA: Intel Cyclone V SE `5CSEMA5F31C6N`
  - HPS: ARM Cortex-A9 Dual-Core @ 800 MHz
  - Memória HPS: 1 GB DDR3
  - Clock FPGA: 50 MHz (padrão)
  - Displays: 6 × 7 segmentos (HEX0–HEX5)
  - Botões: KEY0 (reset), KEY1 (start), KEY2 (ativação)
  -  
---

## Abstração da Estrutura dos Arquivos

```
co-processador-elm-fpga/
    |
    |
    ├── RTL Verilog/
    |   ├── inference_engine/
    │   |   ├── co_processador.v      ← Top-level: integra todos os módulos + ISA 32-bit (5 instruções)
    │   |   ├── fsm.v                 ← Maquina de estados (28 estados)
    │   |   ├── mac.v                 ← Unidade MAC (multiply-accumulate, 32-bit)
    │   |   ├── ativacaoSigm.v        ← Sigmoid piecewise linear (20 segmentos)
    │   |   ├── ativacaoTanh.v        ← Tanh piecewise linear (11 segmentos)
    │   |   ├── argmax.v              ← Argmax sequencial (10 entradas)
    │   |   └── display.v             ← Display 7 segmentos HEX0–HEX5
    |   └── memory/
    │      ├── peso.qip              ← Pesos W_in
    │      ├── bias.qip              ← Bias b
    │      ├── beta.qip              ← Pesos β 
    |      |   └── imagem.qip            ← Pixels 
    |      └── co-processador.qpf          ← Projeto Quartus Prime
    |   
    ├── testbench/
    |   ├── tb_k_vetores/        
    |   ├── tb_modules/        
    |   └── test_reports/         
    |
    ├── Data/
    |   ├── data_function/
    |   └── dataset/
    |
    ├── Diagramas
    │   ├── architecture/
    │   ├── datapath/
    │   └── fsm/
    |
    ├── scripts/
    |    ├── conv_data_mif.py
    |    └── conv_img_mif.py
    └── README.md

```

---

## Arquitetura do Co-processador

### Diagrama de Blocos  --





### ISA — Conjunto de Instruções (32-bit)

| Instrução | Opcode `[31:29]` | Palavras | Descrição |
|---|---|---|---|
| `STORE_IMG` | `000` | 2 | Grava um pixel de 8 bits (normalizado para Q4.12) na RAM de imagem no endereço especificado |
| `STORE_WEIGHTS` | `001` | 2 | Grava um peso Win​ de 16 bits na RAM de pesos da camada oculta no endereço especificado  |
| `STORE_BIAS` | `010` | 2 | Grava o valor de 16 bits na RAM de Bias da camada oculta no endereço especificado  |
| `STORE_BETA` | `011` | 2 | Grava um peso β de 16 bits na RAM de pesos da camada de saída  no endereço especificado |
| `START` | `100` | 1 | Dispara a FSM para iniciar a inferência |
| `STATUS` | `101` | 1 | Comando para leitura do estado interno e do resultado da predição` |

### Resposta STATUS

| `status[1:0]` | Significado | `pred[3:0]` |
|---|---|---|
| `00` | BUSY | `0000` |
| `01` | DONE | dígito predito (0–9) |
| `10` | ERROR | `1111` |

### FSM — 28 Estados

A FSM opera em dois loops sequenciais:

**Camada oculta** — repete 128 vezes (um por neurônio):
```
H_RESET → W_H_RST → H_WAIT_ADDR → H_PRIME → W_H_PRIME → H_WAIT_PIPE → H_RUN (784 ciclos) → H_WAIT_DONE → H_LATCH → W_H_LATCH → H_SIG → W_H_SIG → H_WRITE → W_H_WRITE ──► (próximo neurônio ou O_RESET)
```

**Camada de saída** — repete 10 vezes (uma por classe):
```
O_RESET → W_O_RST → O_WAIT_BETA → O_PRIME → W_O_PRIME → O_WAIT_PIPE → O_RUN (128 ciclos) → O_WAIT_DONE → O_LATCH → W_O_LATCH → O_WRITE → W_O_WRITE ──► (próxima classe ou DONE_ST)
```iam

**Finalização:**
```
DONE_ST: aguarda argmax_done → done=1, pred=pred_wire
```

### Representação Numérica — Q4.12

| Valor real | Hex | Descrição |
|---|---|---|
| `+1.0` | `0x1000` | Máximo de saída da sigmoid |
| `-1.0` | `0xF000` | Mínimo de saída da tanh |
| `+0.5` | `0x0800` | Ponto médio |
| `+7.9997` | `0x7FFF` | Saturação máxima do MAC |
| `-8.0` | `0x8000` | Saturação mínima do MAC |

---

## Instalação e Configuração do Ambiente

### 1. Requisitos

- Intel Quartus Prime Lite 24.1 (ou superior)
- ModelSim-Intel FPGA Starter Edition
- Python 3.10+ com NumPy

### 2. Clonar o repositório

```bash
git clone https://github.com/<usuario>/co-processador-elm-fpga.git
cd co-processador-elm-fpga
```


### 6. Compilar no Quartus



## Testes de Funcionamento

### Estratégia de Validação

Os testes comparam a saída do co-processador RTL com um **golden model em Python** que executa a mesma rede ELM com os mesmos pesos e a mesma aritmética Q4.12.


### Saída esperada da simulação

```

```

### Script de automação

```bash

```

---

## Análise dos Resultados

