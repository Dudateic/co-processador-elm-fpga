#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

/* Declarações das funções assembly */
extern int enviar_imagem(void* lw_virtual, const char* caminho);
extern int abrir_arquivo(const char* caminho);

/* lw_virtual falso - o stub ignora esse valor */
#define LW_VIRTUAL_FAKE ((void*)0xDEADBEEF)

/* Gera um arquivo .raw de teste com N bytes */
static void gerar_arquivo_teste(const char* path, int n_bytes) {
    FILE* f = fopen(path, "wb");
    if (!f) { perror("fopen"); exit(1); }
    for (int i = 0; i < n_bytes; i++) {
        uint8_t val = (uint8_t)(i % 256);
        fwrite(&val, 1, 1, f);
    }
    fclose(f);
    printf("[TESTE] Arquvo '%s' criado com %d bytes.\n\n", path n_bytes);
}

int main(void) {
    const char* arquivo = "/tmp/teste_imagem.raw";

    gerar_arquivo_teste(arquivo, 784);

    printf("[TESTE] Chamando enviar imagem()... \n");
     printf("%-8s %-6s %-14s %-14s %-12s\n",
           "opcode", "addr", "addr(hex)", "data(dec)", "instrução");
    printf("------------------------------------------------------------\n");

    int resultado = enviar_imagem(LW_VIRTUAL_FAKE, arquivo);

    printf("------------------------------------------------------------\n");
    printf("[TESTE] Retorno de enviar_imagem: %d (%s)\n",
           resultado, resultado == 0 ? "SUCESSO" : "ERRO");
 
    return resultado == 0 ? 0 : 1;
}