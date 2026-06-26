# Comparação entre o Golden Model e a FPGA

## Sumário

1. [Objetivo](#1-objetivo)
2. [Estrutura da Pasta](#2-estrutura-da-pasta)
3. [Execução da Avaliação](#3-execução-da-avaliação)
4. [Resultados Experimentais](#4-resultados-experimentais)

   * 4.1 Acurácia Global
   * 4.2 Acertos e Erros
   * 4.3 Acurácia por Dígito
   * 4.4 Matrizes de Confusão
   * 4.5 Comparação das Métricas
5. [Considerações Finais](#5-considerações-finais)

---

# 1. Objetivo

Esta pasta reúne os artefatos produzidos durante a etapa de validação do acelerador **Extreme Learning Machine (ELM)** implementado em FPGA.

O objetivo da avaliação consiste em comparar os resultados produzidos pela implementação em hardware com aqueles obtidos pelo **Golden Model**, desenvolvido em Python, verificando a equivalência funcional entre as duas implementações por meio da análise de métricas quantitativas e qualitativas.

Ao término da avaliação são gerados automaticamente gráficos e matrizes de confusão que subsidiam a análise dos resultados experimentais.

---

# 2. Estrutura da Pasta

```text
comparison/
├── confusion_matrix/
│   ├── comparison_confusion.png
│   ├── fpga_confusion.png
│   └── golden_confusion.png
│
├── metrics/
│   ├── comparison_metrics.png
│   ├── fpga_digit_accuracy.png
│   ├── fpga_errors.png
│   ├── fpga_vs_golden.png
│   ├── golden_error.png
│   └── golden_metrics.png
│
└── README.md
```

---

# 3. Execução da Avaliação

A avaliação deve ser executada a partir da raiz do projeto.

```bash
python scripts/evaluate_model.py \
    --data_root MNIST \
    --model models/model_elm_fp32.npz \
    --fpga_output ../Driver/output
```

Após a execução, todos os resultados são armazenados automaticamente nesta pasta.

---

# 4. Resultados Experimentais

## 4.1 Comparação da Acurácia Global

A Figura 1 apresenta a comparação da acurácia global obtida pelo Golden Model e pela implementação em FPGA.

![Comparação da Acurácia Global](./comparison/metrics/fpga_vs_golden.png)

**Figura 1 — Comparação da acurácia global entre o Golden Model e a FPGA.**

Observa-se elevada proximidade entre as acurácias obtidas pelas duas implementações, indicando que a representação em ponto fixo preservou adequadamente o comportamento do modelo de referência.

---

## 4.2 Acertos e Erros

### Golden Model

![Golden Model](./comparison/metrics/golden_error.png)

**Figura 2 — Distribuição de acertos e erros do Golden Model.**

O gráfico evidencia a predominância de classificações corretas durante o processo de inferência.

### FPGA

![FPGA](./comparison/metrics/fpga_errors.png)

**Figura 3 — Distribuição de acertos e erros da FPGA.**

A distribuição observada é consistente com os resultados produzidos pelo Golden Model, evidenciando a correta implementação do acelerador.

---

## 4.3 Acurácia por Dígito

![Acurácia por Dígito](./comparison/metrics/fpga_digit_accuracy.png)

**Figura 4 — Acurácia obtida para cada classe do conjunto MNIST.**

A análise individual por classe permite identificar os dígitos com maior e menor taxa de acerto, fornecendo uma visão detalhada do desempenho do classificador.

---

## 4.4 Matrizes de Confusão

### Golden Model

![Golden Confusion](./comparison/confusion_matrix/golden_confusion.png)

**Figura 5 — Matriz de confusão do Golden Model.**

### FPGA

![FPGA Confusion](./comparison/confusion_matrix/fpga_confusion.png)

**Figura 6 — Matriz de confusão da implementação em FPGA.**

### Comparação

![Comparison Confusion](./comparison/confusion_matrix/comparison_confusion.png)

**Figura 7 — Comparação entre as matrizes de confusão do Golden Model e da FPGA.**

As matrizes apresentam elevada similaridade, demonstrando que ambas as implementações produzem respostas equivalentes para a maior parte das amostras avaliadas.

---

## 4.5 Comparação das Métricas

### Comparação Geral

![Comparison Metrics](./comparison/metrics/comparison_metrics.png)

**Figura 8 — Comparação entre as métricas obtidas pelo Golden Model e pela FPGA.**

O gráfico resume a acurácia de ambas as implementações e a diferença absoluta entre elas, evidenciando a pequena perda de desempenho decorrente da implementação em hardware.

### Métricas do Golden Model

![Golden Metrics](./comparison/metrics/golden_metrics.png)

**Figura 9 — Acurácia do Golden Model nos conjuntos de treinamento e teste.**

A proximidade entre as acurácias de treinamento e teste demonstra boa capacidade de generalização do modelo utilizado como referência.

---

# 5. Considerações Finais

Os resultados experimentais demonstram que a implementação da rede **Extreme Learning Machine (ELM)** em FPGA reproduz, com elevada fidelidade, o comportamento do Golden Model. A similaridade entre as matrizes de confusão, a proximidade entre as acurácias globais e o reduzido impacto da quantização em ponto fixo evidenciam a corretude funcional do acelerador desenvolvido e validam a arquitetura proposta para execução da inferência em hardware.
