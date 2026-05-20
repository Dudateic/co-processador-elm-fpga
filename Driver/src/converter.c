#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "converter.h"

#define MAX_LINE 25600

typedef enum {
    RADIX_HEX,
    RADIX_DEC
} radix_t;

static radix_t data_radix = RADIX_HEX;

static int is_header(const char *line)
{
    return strstr(line, "WIDTH") ||
           strstr(line, "DEPTH") ||
           strstr(line, "ADDRESS_RADIX") ||
           strstr(line, "DATA_RADIX") ||
           strstr(line, "CONTENT") ||
           strstr(line, "END");
}

static uint32_t parse_value(char *s)
{
    if (data_radix == RADIX_HEX)
        return strtoul(s, NULL, 16);

    return strtoul(s, NULL, 10);
}

/**
 * Converte uma imagem PNG 28x28 para RAW 8 bits.
 *
 * O arquivo de saída conterá exatamente:
 * 28 * 28 = 784 bytes
 *
 * Cada byte representa um pixel de 0–255.
 *
 * @param png_path Caminho da imagem PNG
 * @param raw_path Caminho do arquivo RAW de saída
 * @return 0 em sucesso, -1 em erro
 */
int png_para_raw(const char* png_path, const char* raw_path) {
    int largura, altura, canais;

    // Força carregar em grayscale (1 canal)
    uint8_t* imagem = stbi_load(
        png_path,
        &largura,
        &altura,
        &canais,
        1
    );

    if (!imagem) {
        printf("Erro ao carregar PNG\n");
        return -1;
    }

    // Verifica tamanho
    if (largura != 28 || altura != 28) {
        printf("Erro: imagem deve ser 28x28\n");
        stbi_image_free(imagem);
        return -1;
    }

    FILE* f = fopen(raw_path, "wb");

    if (!f) {
        printf("Erro ao abrir arquivo RAW\n");
        stbi_image_free(imagem);
        return -1;
    }

    // 28x28 = 784 bytes
    fwrite(imagem, 1, 28 * 28, f);

    fclose(f);

    stbi_image_free(imagem);

    return 0;
}

void load_mif_image(const char *filename, uint8_t *buffer)
{
    FILE *fp = fopen(filename, "r");

    if (!fp) {
        perror("erro abrir mif");
        return;
    }

    char line[MAX_LINE];
    uint32_t idx = 0;
    data_radix = RADIX_HEX;

    while (fgets(line, sizeof(line), fp)) {

        if (is_header(line)) {

            if (strstr(line, "DATA_RADIX")) {

                if (strstr(line, "DEC"))
                    data_radix = RADIX_DEC;
                else
                    data_radix = RADIX_HEX;
            }

            continue;
        }

        char *p = strchr(line, ':');

        if (!p)
            continue;

        *p = '\0';

        char *data_str = p + 1;

        while (*data_str == ' ')
            data_str++;

        char *end = strchr(data_str, ';');

        if (end)
            *end = '\0';

        uint32_t value = parse_value(data_str);

        if (idx < 784)
            buffer[idx++] = (uint8_t)value;
    }

    fclose(fp);

    printf("imagem carregada: %u\n", idx);
}

void load_mif_u16(const char *filename,
                  uint16_t *buffer,
                  uint32_t max_count)
{
    FILE *fp = fopen(filename, "r");

    if (!fp) {
        perror("erro abrir mif");
        return;
    }

    char line[MAX_LINE];

    uint32_t idx = 0;
    data_radix = RADIX_HEX;

    while (fgets(line, sizeof(line), fp)) {

        if (is_header(line)) {

            if (strstr(line, "DATA_RADIX")) {

                if (strstr(line, "DEC"))
                    data_radix = RADIX_DEC;
                else
                    data_radix = RADIX_HEX;
            }

            continue;
        }

        char *p = strchr(line, ':');

        if (!p)
            continue;

        *p = '\0';

        char *data_str = p + 1;

        while (*data_str == ' ')
            data_str++;

        char *end = strchr(data_str, ';');

        if (end)
            *end = '\0';

        uint32_t value = parse_value(data_str);

        if (idx < max_count)
            buffer[idx++] = (uint16_t)value;
    }

    fclose(fp);

    printf("dados carregados: %u\n", idx);
}

/**
 * Salva um buffer de uint16_t em arquivo binário raw.
 *
 * @param path      Caminho do arquivo de saída
 * @param buffer    Buffer de dados uint16_t
 * @param count     Número de elementos a salvar
 * @return 0 em sucesso, -1 em erro
 */
int save_bin_u16(const char *path, const uint16_t *buffer, uint32_t count)
{
    FILE *f = fopen(path, "wb");

    if (!f) {
        perror("erro ao abrir arquivo para escrita");
        return -1;
    }

    size_t escritos = fwrite(buffer, sizeof(uint16_t), count, f);

    fclose(f);

    if (escritos != count) {
        printf("Aviso: esperado %u elementos, escrito %zu\n", count, escritos);
        return -1;
    }

    return 0;
}