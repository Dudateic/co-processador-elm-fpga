#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include "hps_0.h"

/* Funções em assembly */
extern volatile void* hps_open(void);
extern int hps_close(volatile void* lw_virtual);

extern int enviar_imagem(volatile void* lw_virtual, const char* caminho);
extern int abrir_arquivo(const char* caminho);

int main(void) {
    volatile void* lw_virtual;
    int fd = -1;

    printf("Olá, Yasuo.\n");
    const char* arquivo = "./saida.raw";


    if ((fd = open("/dev/mem", (O_RDWR | O_SYNC))) == -1) {
        printf("ERRO: O \"/dev/mem\" não foi abrido.\n");
        return -1;
    }

    lw_virtual = mmap(NULL, 0x00005000, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, 0xff200000);

    if (lw_virtual == MAP_FAILED) {
        printf("ERRO: mmap() escafedeu-se.\n");
        close(fd);
        return -1;
    }
    
    printf("Você morreu, Yasuo?\n");

    int resultado = enviar_imagem(lw_virtual, arquivo);
    printf("Ainda está aí, Yasuo?.\n");

    printf("------------------------------------------------------------\n");
    printf("[TESTE] Retorno de enviar_imagem: %d (%s)\n",
           resultado,
           resultado == 0 ? "SUCESSO" : "ERRO");

    int close_result = hps_close(lw_virtual);

    printf("[TESTE] Retorno de hps_close: %d (%s)\n",
           close_result,
           close_result == 0 ? "OK" : "ERRO");

    return (resultado == 0 && close_result == 0) ? 0 : 1;
}