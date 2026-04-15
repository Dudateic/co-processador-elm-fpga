## Testbench do módulo de ativação

O módulo de ativação foi validado por meio de um testbench dedicado, com o objetivo de verificar o correto funcionamento da função sigmoid aproximada implementada em ponto fixo (Q4.12).

Foram utilizados vetores de entrada previamente armazenados em arquivo de memória (`camada1.hex`), os quais foram aplicados sequencialmente ao módulo de ativação.

A saída do hardware (DUT – Device Under Test) foi comparada com os valores esperados gerados e armazenados em um arquivo de referência (`ativacao.hex`), permitindo a análise da precisão da aproximação numérica.

Durante a simulação, também foi realizada a conversão dos valores de ponto fixo para ponto flutuante (real), com o objetivo de facilitar a interpretação dos resultados e a validação qualitativa do comportamento da função.

## Metodologia de teste

- Leitura de entradas a partir de arquivo (`$readmemh`)
- Aplicação sequencial dos vetores no DUT
- Captura da saída do módulo de ativação
- Escrita dos resultados em arquivo de log
- Conversão para formato real para análise comparativa

## Observações

Os resultados obtidos demonstram que a função de ativação implementada apresenta boa aproximação da função sigmoide ideal, respeitando a limitação de precisão imposta pela representação em ponto fixo.

Eventuais discrepâncias observadas são atribuídas à natureza da aproximação piecewise linear utilizada, bem como à quantização dos valores.

## Arquivos gerados

- `saidas/ativacao.hex` → saída do hardware
- `saidas/camada1.hex` → entradas de teste
- Log de simulação com valores em ponto fixo e ponto real

## Conclusão

O módulo de ativação foi validado com sucesso, apresentando comportamento consistente com a função sigmoide esperada dentro das limitações de precisão do sistema.