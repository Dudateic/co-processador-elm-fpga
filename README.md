# Marco 3 — Aplicação C + Validação Completa + Métricas

> **TEC 499 — MI Sistemas Digitais 2026.1 | UEFS**

## Sumário

01. [Visão Geral do Projeto](#1-visão-geral-do-projeto)
02. [Levantamento de Requisitos](#2-levantamento-de-requisitos)
03. [Fundamentação Teórica](#3-fundamentação-teórica)
04. [Arquitetura do Sistema](#4-arquitetura-do-sistema)
05. [Especificação de Hardware e Software](#5-especificação-de-hardware-e-software)
06. [Processo de Desenvolvimento](#6-processo-de-desenvolvimento)
07. [Instalação e Configuração](#7-instalação-e-configuração)
08. [Testes de Funcionamento](#8-testes-de-funcionamento)
09. [Análise dos Resultados](#9-análise-dos-resultados)
10. [Equipe de Desenvolvimento](#10-equipe-de-desenvolvimento)
11. [Referências](#11-referências)


## 1. Visão Geral do Projeto

Este projeto implementa um sistema completo para classificação de dígitos manuscritos utilizando uma rede neural Extreme Learning Machine (ELM) acelerada por hardware na plataforma DE1-SoC. A solução integra um co-processador desenvolvido em FPGA, um driver em Assembly ARM para comunicação via MMIO e uma aplicação em linguagem C responsável pela interação com o usuário e pela validação do sistema.

A aplicação final opera em três modos: inferência a partir de imagens armazenadas em arquivo, inferência a partir de desenhos realizados pelo usuário utilizando mouse e interface VGA, e execução de benchmarks para avaliação de desempenho. Em todos os modos, a aplicação é responsável por carregar ou capturar a imagem, enviá-la ao acelerador implementado na FPGA, aguardar a conclusão do processamento e exibir o dígito classificado.

A comunicação entre software e hardware é realizada através da Lightweight HPS-to-FPGA Bridge, permitindo que o processador ARM acesse os registradores do co-processador por meio de I/O mapeado em memória. O driver Assembly fornece uma camada de abstração para inicialização do hardware, transferência de dados, controle da execução e leitura dos resultados.

Além da classificação individual de imagens, o sistema possui um modo de validação automatizada capaz de processar conjuntos de dados completos, gerando métricas como acurácia, latência média, desvio padrão da latência e throughput. Os resultados são armazenados em arquivos de log para posterior análise, permitindo avaliar tanto a precisão da rede neural quanto o desempenho da aceleração por hardware.

## 2. Levantamento de Requisitos

### Aplicação em C (Usuário)

A aplicação final deve:

* Receber o caminho para a imagem e parâmetros por meio da interface de linha de comando (CLI);
* Enviar a imagem ao driver Linux responsável pela comunicação com o acelerador ELM;
* Receber o resultado da inferência e imprimir o valor predito (`pred`) ao usuário;
* Disponibilizar um modo de classificação individual de imagens;
* Disponibilizar um modo de validação e benchmark;
* Processar **N** imagens durante a execução dos benchmarks;
* Calcular e apresentar as seguintes métricas:

  * Acurácia (%);
  * Latência média;
  * Desvio padrão da latência;
  * Throughput (imagens/s);

* Salvar os resultados da execução em um arquivo de log, preferencialmente no formato CSV.


## 3. Fundamentação Teórica

Esta seção apresenta os conceitos fundamentais utilizados no desenvolvimento do sistema de classificação de dígitos manuscritos implementado em uma arquitetura heterogênea FPGA + ARM. São abordados a arquitetura da plataforma DE1-SoC, o modelo de computação da rede neural Extreme Learning Machine (ELM), os mecanismos de comunicação via MMIO, o conjunto de instruções do acelerador, o processamento de imagens, a representação da interface de entrada baseada em matriz, a validação por dataset e as métricas de desempenho do sistema.

---

### 3.1 Arquitetura da DE1-SoC

A plataforma DE1-SoC integra um processador ARM Cortex-A9 Dual-Core (HPS) e uma FPGA em um único sistema embarcado. Essa arquitetura permite a divisão de tarefas entre software e hardware, onde o HPS executa o sistema operacional Linux e a aplicação em C, enquanto a FPGA implementa o acelerador da rede neural ELM.

A comunicação entre os dois domínios ocorre por meio da Lightweight HPS-to-FPGA Bridge, baseada no protocolo AXI, que permite o mapeamento de registradores do hardware diretamente no espaço de endereçamento do processador.

---

### 3.2 Comunicação por MMIO (Memory-Mapped I/O)

A comunicação entre software e hardware é realizada através de I/O Mapeado em Memória (MMIO), onde registradores da FPGA são acessados como posições de memória.

No Linux embarcado, o acesso ocorre através do arquivo especial `/dev/mem`, permitindo que a região física da FPGA seja mapeada para o espaço virtual da aplicação por meio da chamada `mmap`. Esse mecanismo permite leitura e escrita direta nos registradores do acelerador, eliminando a necessidade de drivers em espaço kernel.

---

### 3.3 Interface de Linha de Comando (CLI)

A aplicação do sistema é controlada por uma Interface de Linha de Comando (CLI), responsável por receber parâmetros de execução, como caminho de imagem, modo de operação e configuração de benchmarks.

Esse modelo permite automação de testes, execução em lote e baixo overhead computacional, sendo adequado para sistemas embarcados e validação experimental.

---

### 3.4 Processamento de Imagens

O sistema utiliza imagens de dígitos manuscritos com resolução de 28×28 pixels em escala de cinza, totalizando 784 pixels por amostra.

Cada imagem é convertida para um vetor unidimensional e enviada ao acelerador FPGA, que realiza a inferência da rede neural ELM e retorna o dígito classificado no intervalo de 0 a 9.

---

### 3.5 Representação da Imagem por Matriz (28×28)

A imagem utilizada como entrada da rede neural é representada internamente por uma matriz bidimensional de dimensões **28 × 28**, na qual cada elemento corresponde à intensidade de um pixel em escala de cinza, assumindo valores no intervalo de 0 a 255.

Durante o processo de desenho, os valores dos pixels são atualizados dinamicamente a partir das interações do usuário. Para reproduzir características semelhantes à escrita manual, a intensidade aplicada em cada ponto é distribuída para os pixels vizinhos segundo uma aproximação discreta de uma função Gaussiana. Dessa forma, o pixel central recebe maior contribuição, enquanto os pixels adjacentes recebem valores progressivamente menores, promovendo a suavização dos traços e reduzindo descontinuidades na imagem gerada.

Essa representação matricial mantém o estado completo da imagem ao longo da execução do sistema, atuando como base para a geração dos dados de entrada da rede neural. Após a finalização do desenho, a matriz bidimensional é linearizada em um vetor unidimensional de 784 elementos, conforme mostrado na Equação 1:

$$
x = \text{reshape}(I_{28 \times 28}) \in \mathbb{R}^{784}
$$

O vetor resultante é então encaminhado ao acelerador implementado na FPGA, onde é realizada a inferência da rede neural e a determinação da classe correspondente ao dígito manuscrito.

---

### 3.6 Modelo da Extreme Learning Machine (ELM)

A Extreme Learning Machine (ELM) é uma rede neural feedforward de camada única oculta, onde os pesos da camada oculta são inicializados aleatoriamente e não são ajustados durante o processamento.

O modelo matemático é definido por:

$$
H = g(W_{in} \cdot x + b)
$$

$$
y = \beta \cdot H
$$

$$
pred = argmax(y)
$$

Onde:

* **x**: vetor de entrada contendo os 784 pixels da imagem;
* **W_in**: matriz de pesos associada à camada oculta;
* **b**: vetor de bias (termos de deslocamento);
* **g(·)**: função de ativação aplicada aos neurônios da camada oculta;
* **β**: matriz de pesos da camada de saída;
* **pred**: classe predita pela rede neural, correspondente a um dos dígitos de 0 a 9.

---

### 3.7 Representação Numérica em Ponto Fixo Q4.12

Para otimizar a implementação em hardware, todas as operações da ELM utilizam representação em ponto fixo no formato Q4.12.

Esse formato utiliza:

* 1 bit de sinal
* 3 bits de parte inteira
* 12 bits de fração

Isso permite representar valores com precisão aproximada de 2⁻¹², reduzindo significativamente o custo de hardware em relação ao ponto flutuante.

---

### 3.8 Conjunto de Instruções do Co-processador (ISA)

A comunicação entre o processador HPS e o acelerador ELM implementado na FPGA é realizada por meio de registradores mapeados em memória. Cada operação é codificada em uma palavra de 32 bits e transmitida ao hardware através de registradores de controle e dados.

O conjunto principal de instruções do acelerador é composto por:

* **STORE_IMG**: armazena a imagem de entrada;
* **STORE_WEIGHTS**: carrega a matriz de pesos **W_in**;
* **STORE_BIAS**: armazena o vetor de bias **b**;
* **STORE_BETA**: carrega os pesos da camada de saída **beta**;
* **START**: inicia o processo de inferência;
* **STATUS**: retorna o estado atual do acelerador e a predição calculada;
* **RESET**: reinicializa o sistema;
* **CYCLES**: retorna a quantidade de ciclos consumidos durante a execução.

Além das instruções associadas ao acelerador ELM, o sistema disponibiliza registradores dedicados ao subsistema gráfico VGA. Esses registradores permitem que o HPS envie comandos para atualização da memória de vídeo, possibilitando a exibição do desenho realizado pelo usuário em tempo real.

A interface VGA utiliza um registrador de 32 bits para representar cada pixel escrito na tela. Nesse registrador são codificados:

* Coordenada horizontal **x**;
* Coordenada vertical **y**;
* Intensidade do canal vermelho **R**;
* Intensidade do canal verde **G**;
* Intensidade do canal azul **B**.

Após a escrita dos dados, um sinal de habilitação (*enable*) é enviado ao controlador VGA, que realiza a atualização da memória gráfica e retorna um sinal de confirmação (*done*) ao processador. Esse mecanismo estabelece um protocolo simples de sincronização entre o software executado no HPS e o hardware responsável pela geração do sinal VGA.

---

### 3.9 Protocolo de Comunicação (Handshake MMIO)

A comunicação entre ARM e FPGA segue um protocolo de sincronização baseado em handshake:

1. O driver escreve a instrução no registrador INST
2. Seta ENABLE = 1
3. FPGA inicia processamento e ativa BUSY
4. Driver realiza polling no STATUS
5. FPGA finaliza e ativa DONE
6. ENABLE é resetado para 0

Esse mecanismo garante sincronização determinística entre software e hardware.

---

### 3.10 Subsistema de Renderização e Interface Gráfica (VGA e Matriz de Entrada)

Embora o sistema utilize saída VGA para visualização, a geração da entrada da rede neural ocorre exclusivamente a partir da matriz 28 × 28, que representa a imagem do usuário.

O subsistema VGA atua apenas como camada de exibição, operando em resolução 320×240, com codificação RGB 3-3-3 (9 bits por pixel) e arquitetura baseada em memória Dual-Port, permitindo leitura contínua pelo controlador e escrita simultânea pelo processador.

Dessa forma, o pipeline gráfico é independente do pipeline de inferência: enquanto o VGA é responsável exclusivamente pela renderização da interface visual, a classificação é realizada a partir da matriz interna 28 × 28, que constitui a única fonte de dados para o modelo.

---

### 3.11 Interface de Desenho e Captura de Entrada

O sistema implementa uma interface de desenho em tempo real baseada na interação do usuário com uma grade de resolução **28 × 28**, permitindo a construção dinâmica da imagem de entrada da rede neural.

A captura de entrada é realizada por meio de dispositivo de mouse PS/2, operando em modo não bloqueante. Os dados brutos do dispositivo são interpretados em pacotes de três bytes, contendo informações de botões e deslocamento relativo nos eixos X e Y. Esses deslocamentos são acumulados e convertidos em coordenadas absolutas na tela.

As coordenadas de tela são então mapeadas para o espaço discreto da matriz 28 × 28 por meio de uma operação de quantização espacial baseada no tamanho de cada célula e na posição inicial da matiz. Esse mapeamento define a célula ativa da grade, permitindo associar o movimento contínuo do mouse a uma estrutura discreta de pixels.

A interação do usuário é controlada por meio dos botões do mouse:

* **Botão esquerdo**: aplica incremento de intensidade na célula ativa (operação de desenho);
* **Botão direito**: realiza a limpeza completa da matriz (reset da imagem);
* **Botão do meio**: exporta a imagem gerada, salva o buffer em formato PNG e inicia o processo de inferência na FPGA.

No processo de exportação, a matriz **28 × 28** é convertida em um buffer linear de pixels e armazenada em disco no formato PNG, por meio da biblioteca **stb_image_write**, uma biblioteca de domínio público amplamente utilizada para escrita de imagens em aplicações embarcadas e de processamento gráfico leve. Dessa forma, a interface de desenho atua como camada de entrada do sistema, estabelecendo a conexão entre a interação humana e o pipeline de inferência implementado em hardware dedicado, tornando o sistema mais flexível e versátil em relação ao seu uso.

---

### 3.12 Validação por Dataset

A validação do sistema é realizada por meio de datasets de imagens rotuladas, utilizados como referência para avaliação da capacidade de inferência do modelo.

Cada amostra processada pelo acelerador é comparada com seu respectivo rótulo esperado, permitindo a quantificação da taxa de acerto e a análise da capacidade de generalização do sistema em diferentes entradas.

---

### 3.13 Geração de Logs e Persistência de Dados

Os resultados obtidos durante a execução são registrados em arquivos no formato CSV, contendo informações relevantes para análise experimental, tais como:

imagem processada;
valor esperado (ground truth);
valor predito pelo modelo;
latência de inferência;
número de ciclos de clock consumidos.

Esses registros permitem a realização de análises estatísticas posteriores, além de garantir rastreabilidade e reprodutibilidade dos experimentos.

---

### 3.14 Métricas de Desempenho

A avaliação do sistema é baseada em métricas de acurácia e desempenho temporal, permitindo caracterizar tanto a qualidade da inferência quanto a eficiência da implementação em hardware.

#### Acurácia

$$
Acc = \left( \frac{\text{Acertos}}{\text{Total}} \right) \times 100
$$

#### Latência Média

$$
\bar{L} = \frac{1}{N} \sum_{k=1}^{N} \frac{Ciclos_k}{f_{clk}}
$$

#### Desvio Padrão da Latência

$$
\sigma_L = \sqrt{\frac{1}{N} \sum_{k=1}^{N} (Ciclos_k - \bar{Ciclos})^2}
$$

#### Throughput

$$
T = \frac{N}{t_{total}}
$$

#### Matriz de Confusão

A avaliação do desempenho do classificador também é complementada pela **matriz de confusão**, que permite analisar a distribuição das predições em relação aos rótulos reais. Essa representação organiza os resultados em uma estrutura (10 \times 10), na qual cada linha corresponde à classe verdadeira e cada coluna corresponde à classe predita.

Formalmente, a matriz de confusão (M) é definida como:

$$
M_{i,j} = \text{número de amostras da classe real } i \text{ classificadas como classe } j
$$

Essa estrutura permite identificar padrões de erro do modelo, como confusões sistemáticas entre classes específicas, além de fornecer uma análise detalhada do desempenho além da acurácia global, evidenciando o comportamento do classificador em cada categoria individual.


## 4. Arquitetura do Sistema

### 4.1 Visão Geral
```
┌──────────────────────────────────────────────┐
│               main.c — Interface             │  C (usuário)
│   (menu, inferência, benchmark, desenho)     │ 
├──────────────────────────────────────────────┤
│   mouse.h  converter.h  metricas.h           │  Camada de aplicação
│   buffers.h  print.h  vga.h  vga_pio.h       │
├──────────────────────────────────────────────┤
│            api.S — Driver ARMv7              │  Baixo nível
├──────────────────────────────────────────────┤
│      Linux Kernel (/dev/mem + mmap2)         │  Espaço de usuário/kernel
├──────────────────────────────────────────────┤
│   LW HPS-to-FPGA Bridge (0xFF200000)         │  Interface de barramento
├──────────────────────────────────────────────┤
│  ┌──────────────────┬────────────────────┐   │
│  │ elm_accel.v      │  Sub-sistema VGA   │   │  FPGA
│  │ (ELM Co-Proc.)   │  (Renderização)    │   │
│  └──────────────────┴────────────────────┘   │
└──────────────────────────────────────────────┘
```

O sistema é organizado em uma arquitetura em camadas que separa claramente a interface de usuário, o driver de baixo nível, o sistema operacional e o acesso ao hardware via barramento HPS–FPGA. No FPGA, o processamento é dividido entre o co-processador de inferência (ELM) e o subsistema VGA, garantindo a separação entre a execução do modelo e a renderização gráfica.

---

### 4.2 Co-processador elm_accel.v

A interface do co-processador com o HPS é:

| Sinal       | Direção | Largura | Descrição                                   |
|-------------|---------|---------|---------------------------------------------|
| clk         | Input   | 1       | Clock do sistema (50 MHz)                   |
| rst         | Input   | 1       | Reset síncrono ativo alto                   |
| instruction | Input   | 32      | Palavra de instrução codificada             |
| enable      | Input   | 1       | Sinal de handshake                          |
| result      | Output  | 32      | Resultado da instrução executada            |
| busy        | Output  | 1       | Co-processador em execução                  |
| done        | Output  | 1       | Instrução atual concluída                   |
| error       | Output  | 1       | Erro durante execução                       |

A unidade de controle do co-processador é implementada como uma FSM (Finite State Machine) com os estados:

ST_IDLE, ST_FETCH, ST_DECODE, ST_EXECUTE, ST_WAIT_W, ST_WAIT_PES, ST_INFER e ST_DONE.

A codificação da instrução segue o seguinte formato de palavra de 32 bits:

opcode → instruction[31:28]
address → instruction[27:16] (ou instruction[16:0] para carregamento de pesos)
data → instruction[15:0]

---

### 4.3 Driver em Assembly ARM (api.S)

O driver é implementado em api.S, com buffers estáticos declarados na seção .bss:

| Buffer         | Tamanho       | Conteúdo                          |
|----------------|---------------|-----------------------------------|
| image_buffer   | 784 bytes     | Pixels da imagem (uint8)          |
| bias_buffer    | 256 bytes     | 128 valores de bias (uint16 Q4.12)|
| beta_buffer    | 2.560 bytes   | 1.280 pesos β (uint16 Q4.12)      |
| pesos_buffer   | 200.704 bytes | 100.352 pesos W_in (uint16 Q4.12) |

#### Rotinas públicas

| Função            | Protótipo C                               | Descrição                                                                    |
|-------------------|-------------------------------------------|------------------------------------------------------------------------------|
| hps_open          | void* hps_open(void)                      | Abre a ponte de comunicação com a FPGA e devolve um ponteiro para acessá-la. Retorna -1 se falhar. |
| hps_close         | void hps_close(void* lw_virtual)        | Fecha a ponte e libera os recursos de memória usados.                         |
| reset_cop         | void reset_cop(void* lw_virtual)        | Reinicia o co-processador, limpando qualquer estado anterior.                   |
| get_result        | int32_t get_result(void* lw_virtual)    | Lê e retorna o último valor presente no registrador de saída do co-processador.                          |
| get_status        | int32_t get_status(void* lw_virtual)    | Pergunta ao co-processador qual é o seu estado atual e retorna a resposta.                        |
| start_inf         | int32_t start_inf(void* lw_virtual)     | Manda o co-processador executar a classificação e aguarda o resultado. Retorna o dígito previsto.            |
| set_activation    | void set_activation(void* lw_virtual, int tipo) | Define qual função de ativação será usada na próxima inferência (0=Tanh, 1=Sigmoid, 2=ReLU).                    |
| get_cycles        | uint32_t get_cycles(void* lw_virtual)   | Retorna quantos ciclos de clock a última inferência levou para ser concluída.                |
| enviar_imagem     | int enviar_imagem(void* lw_virtual)     | Lê o arquivo img.bin e envia os 784 pixels da imagem para o co-processador. Retorna 0 ou -1. |
| enviar_pesos      | int enviar_pesos(void* lw_virtual)      | Lê o arquivo W_in_q.bin e envia os 100.352 pesos da camada oculta. Retorna 0 ou -1. |
| enviar_bias       | int enviar_bias(void* lw_virtual)       | Lê o arquivo b_q.bin e envia os 128 valores de bias. Retorna 0 ou -1. |
| enviar_beta       | int enviar_beta(void* lw_virtual)       | Lê o arquivo beta_q.bin e envia os 1.280 pesos da camada de saída. Retorna 0 ou -1. |

#### Rotinas internas

| Função            | Descrição                                                                                            |
|-------------------|------------------------------------------------------------------------------------------------------|
| send_inst         | Monta a instrução de 32 bits com opcode, endereço e dado, envia ao co-processador e aguarda a confirmação de recebimento.                   |
| send_weight_addr  | Envia apenas o endereço de um peso, sem aguardar confirmação completa, pois o hardware fica esperando o valor logo em seguida.   |
| loop_enable       | Gerencia o protocolo de comunicação com o hardware: sinaliza que há uma instrução, espera o hardware confirmar, e só então libera para a próxima.                    |
| abrir_arquivo     | Abre um arquivo em modo leitura e retorna seu identificador. Retorna -1 se o arquivo não existir.                                              |
| fechar_arquivo    | Fecha um arquivo aberto. Não faz nada se o identificador for inválido.                                                     |

#### Fluxo completo de uma inferência

```
lw = hps_open()         → abre /dev/mem, mmap2 da bridge
reset_cop(lw)           → garante estado inicial limpo no co-processador

── Inicialização (executada uma única vez) ──
enviar_pesos(lw)        → lê W_in_q.bin → 100.352 × (OP_PES_ADDR + OP_PES_DATA)
enviar_bias(lw)         → lê b_q.bin    → 128 × OP_BIAS
enviar_beta(lw)         → lê beta_q.bin → 1.280 × OP_BETA

── Por imagem (repetido para cada classificação) ──
enviar_imagem(lw)       → lê img.bin    → 784 × OP_IMG
result = start_inf(lw)  → OP_START + handshake → lê OUT_BASE
cycles = get_cycles(lw) → OP_CYCLES    → lê OUT_BASE

hps_close(lw)           → munmap
```

---

### 4.4 API Pública e Erros (api.h)

| Função         | Retorno em sucesso | Retorno em erro                |
|----------------|--------------------|--------------------------------|
| hps_open       | Ponteiro válido    | -1 — falha em open/mmap2       |
| enviar_imagem  | 0                  | -1 — falha ao abrir img.bin    |
| enviar_pesos   | 0                  | -1 — falha ao abrir W_in_q.bin |
| enviar_bias    | 0                  | -1 — falha ao abrir b_q.bin    |
| enviar_beta    | 0                  | -1 — falha ao abrir beta_q.bin |

**Tipos de ativação para set_activation (bits [1:0]):**

| Valor        | Função                      |
|--------------|-----------------------------|
| 0b00 ou 0b11 | Tangente hiperbólica (Tanh) |
| 0b01         | Sigmoid                     |
| 0b10         | ReLU                        |

---

### 4.5 Aplicação em C (`main.c`)

A aplicação em C consiste em um programa interativo baseado em terminal, responsável por orquestrar todo o pipeline de inferência da rede neural ELM implementada em FPGA. O sistema gerencia desde a configuração do hardware e carregamento dos parâmetros até a execução de inferências e análise de desempenho.

A arquitetura da aplicação é modular, permitindo a execução independente de cada etapa do fluxo ou a realização completa de testes e benchmarks.

---

### Menu principal

| Opção | Função       | Descrição                                                                     |
| ----- | ------------ | ----------------------------------------------------------------------------- |
| [1]   | Configuração | Carregamento de pesos, bias, beta e seleção de função de ativação             |
| [2]   | Inferência   | Execução da classificação via FPGA (imagem, PNG ou desenho)                   |
| [3]   | Benchmark    | Avaliação de desempenho (acurácia, latência, throughput e matriz de confusão) |
| [4]   | Status       | Exibe estado do co-processador e último resultado                             |
| [0]   | Sair         | Finaliza a aplicação e libera `/dev/mem`                                      |

---

### Submenu: Configuração

| Opção | Função                                    |
| ----- | ----------------------------------------- |
| [1]   | Carregar bias                             |
| [2]   | Carregar weights (W_in)                   |
| [3]   | Carregar beta                             |
| [4]   | Auto-load da rede                         |
| [5]   | Seleção de ativação (Tanh, Sigmoid, ReLU) |
| [0]   | Voltar                                    |

---

### Submenu: Inferência

| Opção | Função                                  |
| ----- | --------------------------------------- |
| [1]   | Desenho de dígito (matriz 28×28)        |
| [2]   | Carregamento de imagem PNG              |
| [3]   | Inferência em lote (dataset por classe) |
| [0]   | Voltar                                  |

---

### Submenu: Benchmark

| Opção | Métrica                              |
| ----- | ------------------------------------ |
| [1]   | Acurácia                             |
| [2]   | Throughput                           |
| [3]   | Latência (média, min, máx)           |
| [4]   | Desvio padrão da latência            |
| [5]   | Matriz de confusão (por classe)      |
| [6]   | Matriz de confusão completa          |
| [7]   | Execução completa com exportação CSV |
| [0]   | Voltar                               |

---

## 5. Especificação de Hardware e Software

### 5.1 Hardware Utilizado

O sistema foi desenvolvido e validado na plataforma embarcada **Terasic DE1-SoC**, que integra processamento ARM e FPGA em um único dispositivo, permitindo comunicação direta via barramento HPS–FPGA.

### Especificação de hardware

| Componente          | Especificação                            |
| ------------------- | ---------------------------------------- |
| Plataforma          | Terasic DE1-SoC                          |
| FPGA                | Intel Cyclone V SoC (5CSEMA5F31C6N)      |
| Processador (HPS)   | ARM Cortex-A9 dual-core @ 800 MHz        |
| Bridge HPS↔FPGA     | Lightweight AXI Bridge (base 0xFF200000) |
| Memória DDR3        | 1 GB                                     |
| Clock FPGA          | 50 MHz                                   |
| Sistema Operacional | Linux embarcado (LEDS/UEFS)              |

---

### 5.2 Software Utilizado

O ambiente de desenvolvimento combina ferramentas de síntese de hardware, compilação cruzada e automação de testes, permitindo a implementação completa do fluxo HPS–FPGA.

### Ferramentas de desenvolvimento

| Software / Ferramenta    | Versão                  | Finalidade                                          |
| ------------------------ | ----------------------- | --------------------------------------------------- |
| Intel Quartus Prime Lite | 18.1                    | Síntese, place-and-route e geração do bitstream     |
| Intel Platform Designer  | incluso                 | Integração HPS–FPGA e configuração da bridge        |
| ARM GCC Cross Compiler   | arm-linux-gnueabihf-gcc | Compilação da aplicação em C                        |
| GNU Assembler (GAS)      | arm-linux-gnueabihf-as  | Montagem do código em Assembly (`api.S`)            |
| GNU Make                 | 4.x                     | Automação do processo de build                      |
| Python                   | 3.10+                   | Scripts de conversão de dados e automação de testes |
| SSH / SCP                | —                       | Transferência de binários para a placa              |
| Git                      | 2.x                     | Controle de versão do projeto                       |

---

## 6. Processo de Desenvolvimento

### 6.1 Integração do IP no Platform Designer

O módulo do co-processador elm_accel foi adicionado ao Platform Designer como periférico Avalon-MM Slave, conectado à Lightweight HPS-to-FPGA Bridge. Os registradores de PIO foram configurados com os offsets 0x20–0x70 dentro da janela de 4 KB. Após recompilação, o arquivo hps_0.h com as constantes de endereço foi feito e incluído no driver.

---

### 6.2 Desenvolvimento do Driver em Assembly

O api.S foi desenvolvido de forma incremental:

**Etapa 1 — Mapeamento MMIO:** Implementação de hps_open e hps_close, validando que a syscall mmap2 retornava um ponteiro válido e que pulsos em RESET_BASE geravam o comportamento esperado no hardware.

**Etapa 2 — Protocolo de handshake:** Implementação de loop_enable e send_inst. A fase crítica foi identificar que omitir a espera por DONE=0 causava instabilidade em transmissões sequenciais. A adição do segundo loop de polling resolveu definitivamente o problema.

**Etapa 3 — Envio de parâmetros:** Implementação de enviar_pesos, enviar_bias e enviar_beta. O envio de pesos exige protocolo de dois passos (OP_PES_ADDR + OP_PES_DATA), o que motivou a criação de send_weight_addr com delay fixo, pois a FPGA permanece em ST_WAIT_PES e não sinaliza DONE=1 para o endereço isoladamente.

**Etapa 4 — Inferência e métricas:** Implementação de start_inf, get_status e get_cycles, completando a API.

---

### 6.3 Link-edição dos Módulos

O api.S é montado pelo GNU Assembler gerando api.o, que é linkado com a aplicação C pelo ARM GCC. O Makefile automatiza todo o processo de compilação cruzada:

```makefile
CC      = arm-linux-gnueabihf-gcc
AS      = arm-linux-gnueabihf-as
CFLAGS  = -O1 -Wall -march=armv7-a
ASFLAGS = -march=armv7-a

all: app

app: main.o api.o
  $(CC) $(CFLAGS) -o app main.o api.o

main.o: main.c api.h hps_0.h converter.h buffers.h
  $(CC) $(CFLAGS) -c main.c

api.o: api.S hps_0.h
  $(AS) $(ASFLAGS) -o api.o api.S
```

---

### 6.4 Aplicação em C (Interface Principal)

A aplicação main.c é responsável pela orquestração completa do sistema, atuando como interface de controle do usuário. Ela implementa um sistema baseado em menu, permitindo:

* Configuração do co-processador (pesos, bias e função de ativação)
* Execução de inferência individual ou em lote
* Execução de benchmarks completos
* Monitoramento de status do hardware

Além disso, a aplicação gerencia todo o ciclo de vida do sistema, desde o mapeamento da memória (/dev/mem) até a liberação dos recursos ao final da execução. O design modular permite alternar entre diferentes modos de operação sem necessidade de recompilação do hardware.

--- 

### 6.5 Subsistema de Entrada: Mouse e Canvas

A interação do usuário é realizada por meio de um mouse PS/2, cuja leitura é feita em modo não bloqueante a partir de /dev/input/mouse0. Os dados são decodificados em pacotes de 3 bytes, representando:

* Estado dos botões
* Deslocamento em X e Y
* Atualização do cursor

Essas informações são convertidas em coordenadas da matriz 28×28, onde ocorre a escrita dos pixels. Um filtro de suavização baseado em distribuição Gaussiana discreta é aplicado para simular escrita manual, aproximando o padrão do dataset de treinamento.

---

### 6.6 Subsistema de Renderização VGA

O sistema inclui um subsistema de saída gráfica implementado via VGA controlado por PIO, responsável pela visualização em tempo real do canvas. A interface vga_pio.h disponibiliza operações como:

* Escrita de pixel individual
* Preenchimento de tela
* Desenho de retângulos e bordas
* Atualização de buffer gráfico

A resolução utilizada é 320×240, com codificação RGB digital, permitindo visualização leve e compatível com o FPGA. Importante destacar que o subsistema VGA atua exclusivamente como camada de visualização, não interferindo na geração da entrada da rede neural, que é derivada diretamente da matriz 28×28.

## 7. Instalação e Configuração

### 7.1 Estrutura do Repositório
```text
co-processador-elm-fpga/
├── Data/                        # Dados do sistema (treino e validação)
│   ├── data_function/          # Funções auxiliares e parâmetros por ativação
│   └── dataset/                # Conjunto de imagens (0–9) para teste/validação
│
├── Driver/                     # Software embarcado executado no HPS (ARM)
│   ├── include/               # Headers do sistema
│   │   ├── api.h              # Interface HPS ↔ FPGA
│   │   ├── vga.h              # Controle do módulo VGA
│   │   ├── mouse.h           # Entrada via mouse
│   │   ├── converter.h       # Pré-processamento de dados
│   │   └── metricas.h        # Cálculo de desempenho
│   │
│   ├── src/                   # Código-fonte da aplicação
│   │   ├── main.c            # Menu principal do sistema
│   │   ├── api.S             # Driver de baixo nível (MMIO + handshake)
│   │   ├── vga_desenho.c     # Renderização via VGA
│   │   ├── mouse.c           # Captura de entrada do usuário
│   │   ├── converter.c       # Conversão de imagens e dados
│   │   └── metricas.c        # Métricas (latência, acurácia, etc.)
│   │
│   ├── obj/                  # Arquivos compilados (.o, .d)
│   └── output/               # Logs e resultados de testes/benchmarks
│
├── RTL Verilog/              # Implementação em hardware (FPGA)
│   ├── hps-fpga_base/        # Sistema SoC integrado (Quartus/Platform Designer)
│   └── rtl_modules/          # Módulos lógicos do sistema
│       ├── inference_engine/ # Co-processador neural (elm_accel)
│       ├── memory/           # Memórias (pesos, bias, imagem, ciclos)
│       └── modulo_vga/       # Controlador gráfico VGA
│
├── testbench/                # Simulações e validação em Verilog
│   ├── tb_k_vetores/        # Conjunto de testes funcionais completos
│   ├── tb_modules/          # Testes unitários de módulos individuais
│   └── test_reports/       # Relatórios gerados pelas simulações
│
├── Assets/                   # Recursos visuais do projeto
│   └── figuras/             # Diagramas e imagens
│
├── scripts/                 # Scripts auxiliares (pré-processamento)
│   ├── conv_data_mif.py     # Conversão de dados para formato MIF
│   └── conv_img_mif.py      # Conversão de imagens para memória FPGA
│
├── Makefile                 # Automação de build (C + Assembly)
├── README.md                # Documentação principal do projeto
└── tree.txt                 # Exportação da estrutura do repositório
```

---

### 7.2 Pré-requisitos

**No computador host:**
- Intel Quartus Prime Lite 18.1 com suporte a Cyclone V
- Toolchain ARM: arm-linux-gnueabihf-gcc e arm-linux-gnueabihf-as

**Na placa DE1-SoC:**
- Linux embarcado inicializado e acessível via SSH
- Acesso a /dev/mem (execução como root)

---

### 7.3 Configuração do Ambiente

1. Clonar o repositório do projeto:
```bash
git clone <url-do-repositorio>
cd co-processador-elm-fpga
```

2. Abrir o projeto no Intel Quartus Prime:
  Importar o arquivo .qpf
  Garantir que o dispositivo selecionado é o 5CSEMA5F31C6N (Cyclone V SoC)
3. Compilar o projeto:
  Executar a compilação completa (Analysis & Synthesis → Fitter → Assembler)

Peço desculpa! Como coloquei blocos de código uns dentro dos outros na resposta anterior, o botão de copiar do chat pode ter-se baralhado.

Aqui tem a **Secção 7.4** num bloco de Markdown limpo e isolado. Pode clicar em "Copiar código" no canto superior direito do bloco abaixo e colar diretamente no seu ficheiro `README.md`:

---

### 7.4 Organização do Diretório de Execução (Ambiente de Runtime na Placa)

Para o correto funcionamento do software no Linux embarcado da **DE1-SoC**, o ambiente de execução deve espelhar os caminhos relativos definidos no código-fonte. O executável principal deve estar na raiz do diretório de trabalho, acompanhado das pastas de dados (`Activations` e `IMG`) e da pasta de trabalho (`bin`), que o programa utilizará para salvar os arquivos binários intermediários gerados em tempo de execução.

A estrutura hierárquica na placa deve ser estritamente a seguinte:

```text
diretorio_de_execucao/
│
├── acelerador_elm             # Executável principal compilado
│

├── Activations/
│   ├── Relu/                  # Contém: b_q.mif, W_in_q.mif e beta_q.mif
│   ├── Sigm/                  # Contém: b_q.mif, W_in_q.mif e beta_q.mif
│   └── Tanh/                  # Contém: b_q.mif, W_in_q.mif e beta_q.mif
│
└── IMG/
    ├── 0/                     # Arquivos .png de teste para o dígito 0
    ├── 1/                     # Arquivos .png de teste para o dígito 1
    └── ...                    # (subpastas até o dígito 9)

```

### Instruções de Configuração no Terminal da Placa:

#### 1. Compilação do sistema

O projeto utiliza um `Makefile` para automatizar todo o processo de compilação e geração do executável. Portanto, basta executar:

```bash
make
````

#### 2. Execução

Após a compilação, execute o sistema a partir da raiz do projeto:

```bash
./acelerador_elm
```

#### 3. Observação

O sistema foi projetado para operar diretamente a partir do diretório raiz, utilizando caminhos relativos para acesso aos arquivos necessários durante a execução.

## 8. Testes de Funcionamento

Os testes de funcionamento do sistema foram realizados com o objetivo de validar a correta integração entre hardware e software, bem como verificar o comportamento do co-processador `elm_accel`, a interface HPS–FPGA, o pipeline de inferência e os módulos auxiliares de entrada, saída e análise de desempenho.

### 8.1 Testes Funcionais do Co-processador

Os testes iniciais focaram na validação do fluxo básico de execução do acelerador em FPGA, verificando:

* Inicialização correta da FSM (`ST_IDLE → ST_FETCH → ST_DECODE → ST_EXECUTE`)
* Processamento adequado das instruções via interface MMIO
* Sincronização dos sinais `enable`, `busy` e `done`
* Escrita e leitura correta do registrador `result`
* Estabilidade do protocolo de handshake em execuções sequenciais

Foi observado que o controle por polling de `done` e `busy` garante execução determinística, evitando sobreposição de instruções.

---

### 8.2 Testes de Inferência

A etapa de inferência foi validada utilizando imagens do dataset organizado por classes (`0` a `9`), além de entradas geradas pelo modo de desenho.

Foram testados:

* Carregamento de imagem 28×28 e conversão para vetor 784
* Execução de inferência individual
* Inferência em lote por diretório
* Consistência entre diferentes funções de ativação (ReLU, Sigmoid e Tanh)
* Correção da saída via módulo de argmax no FPGA

Os resultados mostraram coerência entre entradas esperadas e classes previstas, confirmando o funcionamento do pipeline completo.

---

### 8.3 Testes de Interface (VGA e Mouse)

Os módulos de interface gráfica foram testados para validar a interação com o usuário:

* Renderização da matriz 28×28 no VGA em tempo real
* Exibição do resultado da inferência na saída gráfica
* Resposta correta aos eventos de entrada via mouse
* Desenho contínuo e captura da imagem em buffer
* Conversão correta do input do mouse para matriz de pixels

Esses testes confirmaram a usabilidade do sistema em modo interativo, permitindo validação visual da entrada e da saída do modelo.

---

### 8.4 Testes de Comunicação HPS–FPGA (MMIO)

A interface de comunicação foi testada para garantir integridade no envio de dados:

* Escrita de instruções no co-processador via bridge
* Leitura consistente de status e resultado
* Transferência de pesos, bias e beta
* Validação do protocolo de dois estágios para carregamento de pesos
* Estabilidade em operações consecutivas sem reset

O mapeamento de memória demonstrou comportamento estável e previsível durante toda a execução.

---

### 8.5 Benchmarks de Desempenho

Foram realizados benchmarks mais consolidados para análise quantitativa do sistema, incluindo:

* Acurácia global do modelo
* Throughput (imagens por ciclo/tempo)
* Latência média, mínima e máxima por inferência
* Desvio padrão da latência
* Matriz de confusão completa por classe
* Logs detalhados em formato CSV para análise posterior

Os resultados indicam um comportamento consistente do sistema, com variação controlada de latência e boa estabilidade em execuções repetidas.

## 9. Análise dos Resultados

A partir dos testes de funcionamento descritos na Seção 8, foi possível realizar uma análise global do comportamento do sistema, avaliando tanto aspectos qualitativos quanto quantitativos da solução implementada. Os resultados obtidos demonstram que a arquitetura proposta atinge os objetivos de integração entre HPS e FPGA, além de apresentar desempenho consistente na execução das inferências.

### 9.1 Análise do Co-processador

O co-processador `elm_accel` apresentou comportamento estável durante os testes, com correta transição entre estados da FSM e sincronização adequada dos sinais de controle (`enable`, `busy` e `done`). O uso de uma FSM estruturada em estágios bem definidos reduziu ambiguidades no fluxo de execução e garantiu previsibilidade nas operações.

A comunicação via MMIO se mostrou eficiente, permitindo o envio e recepção de dados sem inconsistências observadas durante execuções sequenciais. O protocolo de handshake também se mostrou robusto, evitando condições de corrida entre o HPS e o FPGA.

---

### 9.2 Desempenho da Inferência

A análise dos resultados de inferência indicou que o sistema é capaz de processar imagens de forma consistente, mantendo coerência entre as classes esperadas e as classes previstas.

Os principais pontos observados foram:

* Boa estabilidade nas predições para o dataset de dígitos (0–9)
* Comportamento consistente entre diferentes funções de ativação
* Correção adequada da etapa de decisão via argmax no hardware
* Baixa variabilidade entre execuções repetidas

A utilização de dados em ponto fixo (Q4.12) também contribuiu para previsibilidade numérica, com erros controlados dentro do esperado para esse tipo de representação.

---

### 9.3 Análise de Desempenho (Benchmarks)

Os benchmarks consolidados indicaram um desempenho satisfatório do sistema, com métricas coerentes entre si:

* **Acurácia:** valores consistentes com o modelo implementado e o dataset utilizado
* **Latência:** variação controlada entre mínimo, médio e máximo, sem picos anômalos
* **Throughput:** adequado para execução sequencial de inferências no FPGA
* **Desvio padrão:** baixo, indicando estabilidade temporal do processamento
* **Matriz de confusão:** distribuição coerente de erros entre classes similares

Esses resultados indicam que o sistema não apenas funciona corretamente, mas também apresenta comportamento previsível sob carga.

---

### 9.4 Análise das Interfaces (VGA e Mouse)

A integração dos módulos de VGA e mouse ampliou significativamente a capacidade de validação do sistema. A interface gráfica permitiu:

* Visualização direta da entrada (imagem 28×28)
* Acompanhamento do resultado da inferência em tempo real
* Interação dinâmica por desenho via mouse

A resposta do sistema a eventos de entrada foi considerada estável, com atualização coerente dos buffers de imagem e sincronização adequada com o pipeline de inferência.

---

### 9.5 Síntese Geral dos Resultados

De forma geral, os resultados obtidos demonstram que o sistema atinge seu objetivo principal: implementar uma arquitetura de inferência embarcada eficiente baseada em FPGA, com integração completa com o HPS.

Destacam-se como pontos positivos:

* Integração consistente entre hardware e software
* Pipeline de inferência funcional e modular
* Estabilidade na comunicação via MMIO
* Bons resultados de desempenho nos benchmarks
* Expansão funcional com VGA e entrada por mouse

Como limitação, observa-se que o sistema ainda opera de forma sequencial, o que restringe o throughput máximo, sendo um ponto possível de otimização futura.

---

### 9.6 Considerações Finais da Análise

O Marco 3 consolidou a implementação completa do sistema de inferência baseado em FPGA, integrando hardware e software em uma arquitetura funcional de co-processamento. Nesta etapa, foi possível unir o núcleo acelerador em Verilog ao controle em software embarcado, permitindo a execução de inferências de uma rede neural ELM com suporte a carregamento de parâmetros, pré-processamento de imagens e coleta de métricas de desempenho.

A interface entre o HPS e o FPGA, baseada no modelo de memória mapeada (MMIO), demonstrou-se adequada para o controle do co-processador, viabilizando a troca de instruções, dados e resultados de forma estruturada. A implementação da FSM no módulo elm_accel.v garantiu o gerenciamento correto dos estágios de execução, incluindo leitura de instruções, carregamento de pesos, processamento e finalização das operações.

No lado do software, a aplicação em C permitiu a criação de um fluxo interativo e modular, com suporte a configuração da rede, execução de inferência e geração de benchmarks. Além disso, o driver em Assembly assegurou o controle de baixo nível do hardware, sendo essencial para o gerenciamento do protocolo de handshake e sincronização com a FPGA.

Como extensões relevantes do sistema, destacam-se ainda o mapeamento da memória da FPGA, o uso do módulo de VGA para visualização da entrada e saída do sistema em tempo real, e a integração de controle via mouse para interação direta com o ambiente de inferência, ampliando a usabilidade da plataforma para testes mais intuitivos.

Por fim, os benchmarks foram significativamente aprimorados e consolidados, incluindo métricas de acurácia, latência média, throughput, desvio padrão e matrizes de confusão completas. Esses resultados permitiram uma análise mais robusta do desempenho do sistema, validando não apenas sua funcionalidade, mas também sua eficiência e estabilidade em cenários de teste mais amplos.

Dessa forma, o sistema atinge o objetivo proposto no Marco 3, demonstrando uma solução completa de inferência embarcada com integração HPS–FPGA, enriquecida por interfaces gráficas, controle interativo e análise de desempenho avançada, com potencial de expansão para aplicações mais complexas.

## 10. Equipe de Desenvolvimento

O presente projeto foi desenvolvido por Maria Eduarda Teixeira Costa, Taylon Luis do Nascimento Cerqueira e Yasmim de Paula Oliveira.


## 11. Referências

- LEDS – Laboratório de Eletrônica Digital e Sistemas (UEFS)
  https://sites.google.com/uefs.br/ltec3-leds

- FPGA Academy – Boards and Learning Resources
  https://fpgacademy.org/boards.html

- Intel — Cyclone V SoC: HPS Technical Reference Manual
  https://www.intel.com/content/www/us/en/programmable/hps/cyclone-v/hps.html

- Intel — DE1-SoC User Manual (Lightweight HPS-to-FPGA Bridge)
  https://fpgacademy.org/Downloads/Intel_DE1-SoC_User_Manual.pdf

- ARM — Architecture Reference Manual ARMv7-A and ARMv7-R Edition
  https://developer.arm.com/documentation/ddi0406/latest/

- ARM — Procedure Call Standard for the ARM Architecture (AAPCS)
  https://developer.arm.com/documentation/ihi0042/latest/

- CHEN, Guang-Bin et al. Extreme Learning Machine: Algorithm, Theory and Applications
  https://www.researchgate.net/publication/257512921_Extreme_learning_machine_algorithm_theory_and_applications

- Accelerating Extreme Learning Machine on FPGA Hardware Implementation of Given Rotation - QRD
  https://publisher.uthm.edu.my/ojs/index.php/ijie/article/view/4431

- Digital Design and Computer Architecture – Harris & Harris

- Linux Device Drivers, 3rd Edition – Corbet, Rubini, Kroah-Hartman
  https://lwn.net/Kernel/LDD3/

### 11.1 Bibliotecas de Terceiros

- **stb_image.h** — Sean Barrett (@nothings)
  Biblioteca *single-file header* em C (Domínio Público / MIT License) utilizada no módulo para a decodificação de imagens PNG e conversão direta para o formato de pixels RAW em escala de cinza (8-bits). 
  Repositório oficial: https://github.com/nothings/stb

- **stb_image_write.h** — Sean Barrett (@nothings)
  Biblioteca single-header em linguagem C utilizada para escrita de imagens em arquivos nos formatos PNG, BMP e TGA. Neste projeto, foi empregada para exportar o buffer do Canvas 28×28 gerado pelo sistema de desenho do usuário, permitindo   salvar visualmente as entradas utilizadas na inferência da rede neural.
  Repositório oficial: https://github.com/nothings/stb