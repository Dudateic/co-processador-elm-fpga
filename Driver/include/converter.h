#ifndef CONVERTER_H
#define CONVERTER_H

#include <stdint.h>

/**
 * Converte uma imagem PNG 28x28 para RAW de 8 bits em escala de cinza.
 * Grava exatamente 784 bytes no arquivo raw_path.
 * @return 0 em sucesso, -1 em erro.
 */
int convert_png_to_raw(const char *png_path, uint8_t *buffer, size_t buffer_size);

/**
 * Faz o parse de um arquivo MIF e carrega os valores num buffer uint8_t.
 * @return 0 em sucesso, -1 em erro.
 */
int load_mif_to_u8(const char *filename, uint8_t *buffer, uint32_t max_count);

/**
 * Faz o parse de um arquivo MIF e carrega os valores num buffer uint16_t.
 * @return 0 em sucesso, -1 em erro.
 */
int load_mif_to_u16(const char *filename, uint16_t *buffer, uint32_t max_count);

/**
 * Persiste um buffer uint16_t num arquivo binário RAW.
 * @return 0 em sucesso, -1 em erro.
 */
int save_u16_to_bin(const char *path, const uint16_t *buffer, uint32_t count);

#endif