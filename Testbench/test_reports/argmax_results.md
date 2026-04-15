## Módulo Argmax

O módulo `argmax` é responsável pela etapa final de decisão da rede neural implementada em hardware. Sua função consiste em identificar o índice do maior valor entre as saídas dos neurônios da camada final, correspondendo à classe predita pelo sistema.

## Funcionamento

O módulo recebe sequencialmente os valores de saída (`y_in`) associados a um índice (`idx`) e realiza a comparação com o maior valor armazenado internamente (`max_val`).

A cada ciclo de clock, caso o valor de entrada seja maior que o valor máximo atual, o sistema atualiza:
- o valor máximo (`max_val`)
- o índice correspondente (`pred`)

O sinal `done` é ativado quando o último índice da camada de saída é processado, indicando a finalização da operação.

## Inicialização

Durante o reset:
- `pred` é zerado
- `max_val` é inicializado com o menor valor possível em complemento de dois (16'h8000)
- `done` é desativado

## Observações

Este módulo implementa uma versão sequencial do operador argmax, sendo adequado para hardware de baixo custo, pois utiliza apenas comparadores e registradores, sem necessidade de operações complexas.