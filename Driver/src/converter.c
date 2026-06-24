#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#define STB_IMAGE_WRITE_IMPLEMENTATION
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
#include "stb_image_write.h"
#pragma GCC diagnostic pop

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "converter.h"

#define MIF_MAX_LINE_LENGTH 2048 // Tamanho reduzido para um buffer de linha seguro e eficiente

// Enumeração para rastrear a base numérica do arquivo MIF
typedef enum {
    RADIX_HEX,
    RADIX_DEC
} mif_radix_t;

// ============================================================================
// FUNÇÕES AUXILIARES PRIVADAS (Lógica Interna)
// ============================================================================

/**
 * Verifica se a linha atual pertence ao cabeçalho do arquivo MIF.
 */
static int is_mif_header(const char *line) {
    return strstr(line, "WIDTH") ||
           strstr(line, "DEPTH") ||
           strstr(line, "ADDRESS_RADIX") ||
           strstr(line, "DATA_RADIX") ||
           strstr(line, "CONTENT") ||
           strstr(line, "END");
}

/**
 * Processa uma única linha do arquivo MIF.
 * * @param line Linha de texto lida do arquivo.
 * @param out_value Ponteiro para armazenar o valor numérico extraído.
 * @param current_radix Ponteiro para o estado atual da base numérica (Hex/Dec).
 * @return 1 se um valor foi extraído, 0 se for cabeçalho/vazio.
 */
static int parse_mif_line(char *line, uint32_t *out_value, mif_radix_t *current_radix) {
    // Tratamento de cabeçalho e atualização da base numérica
    if (is_mif_header(line)) {
        if (strstr(line, "DATA_RADIX")) {
            if (strstr(line, "DEC")) {
                *current_radix = RADIX_DEC;
            } else {
                *current_radix = RADIX_HEX;
            }
        }
        return 0; // Nenhum dado extraído nesta linha
    }

    // Procura o delimitador ':' que separa endereço de dado
    char *colon_ptr = strchr(line, ':');
    if (!colon_ptr) return 0;

    *colon_ptr = '\0';
    char *data_str = colon_ptr + 1;

    // Ignora espaços em branco antes do número
    while (*data_str == ' ' || *data_str == '\t') {
        data_str++;
    }

    // Remove o ponto e vírgula do final
    char *semicolon_ptr = strchr(data_str, ';');
    if (semicolon_ptr) {
        *semicolon_ptr = '\0';
    }

    // Converte a string para número com base no radix atual
    int base = (*current_radix == RADIX_HEX) ? 16 : 10;
    *out_value = (uint32_t)strtoul(data_str, NULL, base);

    return 1; // Sucesso na extração
}


// ============================================================================
// FUNÇÕES PÚBLICAS (API)
// ============================================================================


/**
 * Converte uma imagem PNG 28x28 para RAW de 8 bits em escala de cinza.
 * O arquivo RAW de saída conterá exatamente 784 bytes.
 *
 * @param png_path Caminho da imagem PNG de entrada.
 * @param raw_path Caminho do arquivo RAW binário de saída.
 * @return 0 em caso de sucesso, -1 em caso de erro.
 */
int convert_png_to_raw(const char* png_path, uint8_t* buffer, size_t buffer_size) {
    int largura, altura, canais;

    // Força o carregamento da imagem em escala de cinza (1 canal)
    uint8_t* imagem = stbi_load(png_path, &largura, &altura, &canais, 1);


    if (!imagem) {
        fprintf(stderr, "Erro: Nao foi possivel carregar o arquivo PNG '%s'\n", png_path);
        return -1;
    }

    // Validação estrita das dimensões requeridas pela rede neural
    if (largura != 28 || altura != 28) {
        fprintf(stderr, "Erro: A imagem deve ser exatamente 28x28 pixels (encontrado %dx%d)\n", largura, altura);
        stbi_image_free(imagem);
        return -1;
    }

    if (buffer_size < 784) {
        fprintf(stderr, "Erro: O buffer de destino para a imagem RAW e muito pequeno.\n");
        stbi_image_free(imagem);
        return -1;
    }

    memcpy(buffer, imagem, 784);
    stbi_image_free(imagem);
    return 0;
}

/**
 * Faz o parse de um arquivo MIF e carrega os valores para um buffer de 8 bits (uint8_t).
 * Utilizado primariamente para carregar a matriz da imagem (784 posições).
 *
 * @param filename Caminho do arquivo .mif
 * @param buffer Ponteiro para o buffer de destino
 * @param max_count Tamanho máximo do buffer para evitar overflow
 * @return 0 em caso de sucesso, -1 em caso de erro
 */
int load_mif_to_u8(const char *filename, uint8_t *buffer, uint32_t max_count) {
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        fprintf(stderr, "Erro: Falha ao abrir o arquivo MIF '%s'\n", filename);
        return -1;
    }

    char line[MIF_MAX_LINE_LENGTH];
    uint32_t idx = 0;
    uint32_t parsed_value = 0;
    mif_radix_t current_radix = RADIX_HEX; // Padrão inicial

    while (fgets(line, sizeof(line), fp)) {
        if (parse_mif_line(line, &parsed_value, &current_radix)) {
            if (idx < max_count) {
                buffer[idx++] = (uint8_t)parsed_value;
            }
        }
    }

    fclose(fp);
    printf(">> Arquivo '%s' carregado: %u dados extraídos (8-bit).\n", filename, idx);
    return 0;
}

/**
 * Faz o parse de um arquivo MIF e carrega os valores para um buffer de 16 bits (uint16_t).
 * Utilizado para carregar Pesos, Bias e Betas.
 *
 * @param filename Caminho do arquivo .mif
 * @param buffer Ponteiro para o buffer de destino
 * @param max_count Tamanho máximo do buffer para evitar overflow
 * @return 0 em caso de sucesso, -1 em caso de erro
 */
int load_mif_to_u16(const char *filename, uint16_t *buffer, uint32_t max_count) {
    FILE *fp = fopen(filename, "r");
    if (!fp) {
        fprintf(stderr, "Erro: Falha ao abrir o arquivo MIF '%s'\n", filename);
        return -1;
    }

    char line[MIF_MAX_LINE_LENGTH];
    uint32_t idx = 0;
    uint32_t parsed_value = 0;
    mif_radix_t current_radix = RADIX_HEX; // Padrão inicial

    while (fgets(line, sizeof(line), fp)) {
        if (parse_mif_line(line, &parsed_value, &current_radix)) {
            if (idx < max_count) {
                buffer[idx++] = (uint16_t)parsed_value;
            }
        }
    }

    fclose(fp);
    printf(">> Arquivo '%s' carregado: %u dados extraídos (16-bit).\n", filename, idx);
    return 0;
}

/**
 * Persiste um buffer contendo dados de 16 bits num ficheiro RAW binário.
 * Útil para enviar blocos de memória puros para o processador/FPGA.
 *
 * @param path Caminho do arquivo de saída
 * @param buffer Ponteiro para os dados uint16_t
 * @param count Número total de elementos a gravar
 * @return 0 em sucesso, -1 em caso de erro
 */
int save_u16_to_bin(const char *path, const uint16_t *buffer, uint32_t count) {
    FILE *f = fopen(path, "wb");
    if (!f) {
        fprintf(stderr, "Erro: Nao foi possivel criar o arquivo binario '%s'\n", path);
        return -1;
    }

    size_t escritos = fwrite(buffer, sizeof(uint16_t), count, f);
    fclose(f);

    if (escritos != count) {
        fprintf(stderr, "Alerta: Inconsistencia na gravacao de '%s'. Esperados %u elementos, gravados %zu.\n", path, count, escritos);
        return -1;
    }

    return 0;
}