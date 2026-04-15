# Testbench do módulo MAC

O diretório contém dois testbenches distintos para validação do módulo MAC:

## 1. Camada Oculta (Hidden Layer)

Este testbench simula a primeira camada da rede neural, processando:
- 784 entradas (pixels)
- 128 neurônios
- pesos armazenados em memória externa

A saída de cada neurônio é armazenada e exportada para arquivo, sendo utilizada como entrada da etapa seguinte (função de ativação).

## 2. Camada de Saída (Output Layer)

Este testbench utiliza como entrada os valores processados pela camada oculta após ativação.
- 128 entradas
- 10 neurônios de saída
- realiza a classificação final

Além disso, implementa lógica de seleção do maior valor (argmax) diretamente no testbench para validação da predição final.

## Arquivos gerados

- `camada1.hex` → saída da camada oculta
- `saida_final.hex` → saída da camada de saída

## Observações

Os testes utilizam leitura de memória via `$readmemh` e execução sequencial controlada por task (`run_neuron`), garantindo sincronização correta com o sinal `done` do MAC.

Esse método permite validação modular e integração gradual da rede neural em hardware.