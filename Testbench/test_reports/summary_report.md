# Summary Report – Testes do Coprocessador FPGA

## 1. Objetivo dos Testes

Os testes foram desenvolvidos para validar o funcionamento do coprocessador FPGA implementado, garantindo conformidade com o **golden model (software)**.

Foram verificados os seguintes módulos:

- `MAC`
- `ativacaoSigm / ativacaoTanh`
- `argmax`

---

## 2. Estratégia de Validação

A metodologia de verificação adotada foi baseada em:

- Testbenches em Verilog
- Leitura de vetores `.hex` fornecidos pelo professor
- Comparação com golden model (software)
- Geração de arquivos de saída para análise

---

## 3. Vetores de Teste (K vetores)

Foram utilizados **K vetores de entrada fornecidos pelo professor**, aplicados diretamente nos testbenches.

### Resultados gerais:
- A maioria dos vetores apresentou **inferência correta**


---

## 4. Resultados por Módulo

### 4.1 Teste do MAC

- Entrada: imagens e pesos (`784 entradas`)
- Saída: soma acumulada com bias
- Arquivo gerado: `camada1.hex`

✔ Resultado:
- Alta consistência com o golden model  
- Pequenos erros devido a:
  - Quantização (Q-format)
  - Shift fixo
  - Saturação

---

### 4.2 Teste da Função de Ativação

- Módulos testados:
  - Sigmoid aproximada
  - Tanh aproximada

- Arquivo gerado:
  - `ativacao.hex`

✔ Resultado:
- Boa aproximação da curva real
- Erros mais perceptíveis em regiões de transição
- Impacto leve na classificação final

---

### 4.3 Teste do Argmax

- Função: selecionar maior valor entre classes

✔ Resultado:
- Funcionamento correto
- Sem divergência funcional detectada
- Sensível apenas a erros do MAC/ativação

---

### 4.4 Teste do Sistema Completo (FSM)

- Pipeline completo executado:
  - MAC → Ativação → Argmax

✔ Resultado:
- Inferência correta na maioria dos vetores
- Arquivo final: `saida_final.hex`

---

## 5. Comparação com Golden Model

### Critério de avaliação:
- Igualdade exata de classe
- Comparação de saída intermediária

### Resultado geral:

| Métrica              | Resultado |
|---------------------|----------|
| Acurácia geral      | Alta     |
| Erros críticos      | Baixos   |
| Diferença média     | Pequena  |

---

## 6. Análise dos Erros

Os erros encontrados foram analisados e apresentaram padrões:

- Erros em classes próximas (valores muito similares)
- Influência da quantização fixa (Q-format) provocando um acúmulo de erros ao longo do MAC
- Aproximação das funções de ativação

---

## 7. Conclusão dos Testes

Os testes confirmam que:

- O sistema está **funcional e consistente**
- O pipeline de inferência está correto
- Pequenas divergências são esperadas devido à implementação em ponto fixo

---

## 8. Considerações Finais

Apesar de pequenas variações numéricas, o sistema apresenta:

- Funcionamento correto do datapath
- Boa correspondência com o modelo de referência

