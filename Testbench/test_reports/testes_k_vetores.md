## Avaliação com K vetores de teste

Foram utilizados K vetores de teste fornecidos pelo professor, os quais foram comparados com os resultados gerados pelo golden model.

De forma geral, a maior parte das amostras apresentou inferência correta, demonstrando o comportamento esperado do sistema implementado. No entanto, uma pequena parcela dos vetores apresentou resultados incorretos na inferência.

Após análise dessas amostras divergentes, observou-se a presença de padrões e similaridades entre os casos de erro, sugerindo que determinadas características dos dados de entrada influenciam diretamente na degradação da precisão do modelo em hardware.

Esses resultados indicam que, embora a implementação esteja funcional, ainda existem limitações numéricas e/ou de aproximação (como quantização, função de ativação aproximada ou truncamentos) que impactam a acurácia final do sistema.

### Arquivo adicional
Foi incluído no repositório um arquivo específico contendo:
- lista dos vetores de teste utilizados
- saídas do hardware (DUT)
- saídas do golden model
- identificação dos casos incorretos
- análise comparativa dos erros

Esse arquivo permite rastreabilidade completa dos testes e facilita a análise de divergências entre o modelo ideal e a implementação em hardware.