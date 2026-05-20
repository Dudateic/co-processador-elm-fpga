#include <stdio.h>
#include <stdint.h>

#include "api.h"
#include "hps_0.h"
#include "buffers.h"
#include "converter.h"

int main()
{
    printf("\n--- ACELERADOR NEURAL ELM - START ---\n");

    // Inicializa e abre a ponte de comunicação física
    void* lw_virtual = hps_open();

    // Validação correta de erro de acordo com a documentação do seu .h
    if (lw_virtual == (void*)-1 || lw_virtual == NULL) {
        printf("Erro fatal: Não foi possível mapear a memória da FPGA.\n");
        return 1;
    }

    // Dá um pulso de reset inicial no coprocessador para limpar sujeiras
    reset_cop(lw_virtual);

    int option;
    char filename[256];
    int32_t status;
    int32_t ciclos;
    int r;

    int32_t soma_ciclos = 0;
    int erros = 0;

    while (1) {
        printf("\n==================================\n");
        printf("[0] Status\n");
        printf("[1] Enviar imagem\n");
        printf("[2] Enviar bias\n");
        printf("[3] Enviar weights\n");
        printf("[4] Enviar beta\n");
        printf("[5] Inferencia\n");
        printf("[6] Inferencia x10\n");
        printf("[7] Mudar Funçao de Ativaçao\n");
        printf("[8] Sair\n");
        printf("==================================\n");
        printf("=> ");
        
        if (scanf("%d", &option) != 1) {
            while (getchar() != '\n'); // Limpa lixo do buffer do teclado
            continue;
        }

        switch (option) {
            case 0:
                // Coleta o status através da instrução dedicada do hardware
                status = get_status(lw_virtual);
                printf("\nStatus Bruto: 0x%08X\n", status);
                // Ajustado conforme o empacotamento de bits do circuito elm_accel:
                printf("  Done: %u\n", (status >> 11) & 1);
                printf("  Busy: %u\n", (status >> 10) & 1);
                printf("  Pred: %u\n", status & 0xF);
                break;

            case 1:
                printf("Digite o nome da imagem original (ex: digito.png, teste.jpg):\n=> ");
                scanf("%255s", filename);

                // Converte a imagem direto no HPS e salva como "0.bin" (definido em buffers.h/api.h)
                // Usamos a macro image_file que você já possui definida no projeto
                r = png_para_raw(filename, image_file);
                
                if (r == 0) {
                    // Se a conversão deu certo, chama a sua função em Assembly para mandar para a FPGA
                    r = enviar_imagem(lw_virtual);
                    if (r == 0) printf(">> Imagem RAW de 8 bits enviada com sucesso para a FPGA!\n");
                    else        printf(">> ERRO: Falha na transmissao do Assembly para a FPGA.\n");
                } else {
                    printf(">> ERRO na preparaçao dos pixels. Transmissao abortada.\n");
                }

                break;
            case 2:
                printf("bias.mif: ");
                scanf("%255s", filename);

                load_mif_u16(filename, buffer_bias, N_bias);
                save_bin_u16(bias_file, buffer_bias, N_bias);

                r = enviar_bias(lw_virtual);
                if (r == 0) printf("Bias enviado com sucesso!\n");
                else        printf("Erro ao enviar Bias.\n");
                break;

            case 3:
                printf("weights.mif: ");
                scanf("%255s", filename);

                load_mif_u16(filename, buffer_weights, N_pesos);
                save_bin_u16(pesos_file, buffer_weights, N_pesos);

                r = enviar_pesos(lw_virtual);
                if (r == 0) printf("Weights enviados com sucesso!\n");
                else        printf("Erro ao enviar weights.\n");
                break;

            case 4:
                printf("beta.mif: ");
                scanf("%255s", filename);

                load_mif_u16(filename, buffer_beta, N_beta);
                save_bin_u16(beta_file, buffer_beta, N_beta);

                r = enviar_beta(lw_virtual);
                if (r == 0) printf("Beta enviado com sucesso!\n");
                else        printf("Erro ao enviar beta.\n");
                break;

            case 5:
                printf("Disparando inferência...\n");
                // start_inf já engatilha o hardware e espera (polling) o fim da execução
                status = start_inf(lw_virtual); 
                ciclos = get_cycles(lw_virtual);

                if (status >= 0) {
                    printf("Inferencia OK\n");
                    printf("Pred: %u\n", status & 0xF);
                    printf("Tempo de execução: %d ciclos de clock\n", ciclos);
                } else {
                    printf("Erro inferencia (Código de erro: %d)\n", status);
                }
                break;

            case 6:
                printf("Executando bateria de benchmark (x10 inferências)...\n");
                soma_ciclos = 0;
                erros = 0;

                for (int i = 0; i < 10; i++) {
                    status = start_inf(lw_virtual);
                    ciclos = get_cycles(lw_virtual);

                    if (status >= 0) {
                        printf("  Inferencia %d OK | Pred: %u | %d ciclos\n", i + 1, status & 0xF, ciclos);
                        soma_ciclos += ciclos;
                    } else {
                        printf("  Erro na inferência %d\n", i + 1);
                        erros++;
                    }
                }
                if (erros < 10) {
                    printf(">> Média de tempo do hardware: %.1f ciclos de clock\n", (float)soma_ciclos / (10 - erros));
                }
                break;

            case 7:
                printf("Escolha a funçao de ativaçao:\n");
                printf(" [0] Tangente Hiperbólica (Tanh)\n");
                printf(" [1] Sigmoide\n");
                printf(" [2] ReLU\n");
                printf("=> ");
                int ativacao_escolhida;
                scanf("%d", &ativacao_escolhida);
                if (ativacao_escolhida >= 0 && ativacao_escolhida <= 2) {
                    set_activation(lw_virtual, ativacao_escolhida);
                    printf("Funçao de ativaçao atualizada na FPGA!\n");
                } else {
                    printf("Opçao inválida.\n");
                }
                break;

            case 8:
                printf("Encerrando mapeamento e saindo de forma limpa...\n");
                hps_close(lw_virtual);
                return 0;

            default:
                printf("Opcao invalida\n");
        }
    }

    return 0;
}