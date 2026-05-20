#ifndef API_H
#define API_H

#include <stdint.h>

/**
 * @brief Inicializa o HPS e mapeia a ponte Lightweight de memória da FPGA.
 * @return `void*`, ponteiro para a base virtual mapeada (lw_virtual), ou `-1` (0xFFFFFFFF) em caso de erro.
 */ 
void* hps_open(void);

/**
 * @brief Encerra o mapeamento de memória da FPGA de forma limpa.
 * @param lw_virtual Ponteiro retornado por hps_open.
 */
void hps_close(void* lw_virtual);

/**
 * @brief Envia um pulso de reset para o coprocessador.
 * @param lw_virtual Ponteiro retornado por hps_open.
 */
void reset_cop(void* lw_virtual);

/**
 * @brief Lê o resultado exportando no registrador de saída do coprocessador.
 * @param lw_virtual Ponteiro retornado por hps_open.
 * @return `int32_t` Valor bruto contino no registrador de saída.
 */
int32_t get_result(void* lw_virtual);

/**
 * @brief Envia uma instrução de Status para o coprocessador.
 * @param lw_virtual Ponteiro retornado por hps_open.
 * @return `int32_t` Valor bruto contino no registrador de saída após a instrução ser finalizada.
 */
int32_t get_status(void* lw_virtual);

/**
 * @brief Dispara o sinal de início de inferência no co-processador e aguarda o término.
 * @param lw_virtual Ponteiro da base virtual.
 * @return `int32_t` Valor bruto contino no registrador de saída após a inferência ser terminada.
 */
int32_t start_inf(void* lw_virtual);

/**
 * @brief Altera qual função de ativação usar na inferência.
 * @param lw_virtual Ponteiro da base virtual.
 * @param tipo_actv Tipo da ativação
 * @note 00 ou 11: Tangente
 * @note 01: Sigmoid
 * @note 10: RELU
 * @warning Lê apenas os últimos 2 bits da instrução para escolher.
 */
void set_activation(void* lw_virtual, int tipo_ativacao);

/**
 * Retorna o valor do contador de ciclos calculado na última inferência.
 * @param lw_virtual Ponteiro da base virtual.
 * @return `int32_t` do valor calculado de ciclos na inferência.
 */
int32_t get_cycles(void* lw_virtual);

/**
 * @brief Abre o arquivo "0.bin" e transmite os 784 pixels da imagem para a FPGA.
 * @param lw_virtual Ponteiro da base virtual.
 * @return int `0` em caso de sucesso, `-1` se houver erro ao abrir o arquivo.
 */
int enviar_imagem(void* lw_virtual);

/**
 * @brief Abre o arquivo "W_in_q.bin" e transmite os 100.352 pesos para a FPGA (2 etapas por peso).
 * @param lw_virtual Ponteiro da base virtual.
 * @return int `0` em caso de sucesso, `-1` se houver erro ao abrir o arquivo.
 */
int enviar_pesos(void* lw_virtual);

/**
 * @brief Abre o arquivo "b_q.bin" e transmite os 128 biases para a FPGA.
 * @param lw_virtual Ponteiro da base virtual.
 * @return int `0` em caso de sucesso, `-1` se houver erro ao abrir o arquivo.
 */
int enviar_bias(void* lw_virtual);

/**
 * @brief Abre o arquivo "beta_q.bin" e transmite os 1280 betas para a FPGA.
 * @param lw_virtual Ponteiro da base virtual.
 * @return int `0` em caso de sucesso, `-1` se houver erro ao abrir o arquivo.
 */
int enviar_beta(void* lw_virtual);

#endif