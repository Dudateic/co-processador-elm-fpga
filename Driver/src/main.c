#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <dirent.h>
#include <stdbool.h>

#include "api.h"
#include "hps_0.h"
#include "buffers.h"
#include "converter.h"

/* ========================================================================= */
/* FUNÇÕES AUXILIARES DE TELEMETRIA E TESTE                                  */
/* ========================================================================= */

void show_status(uint32_t status) {
    uint32_t wait_w = (status >> 9) & 1;
    uint32_t done   = (status >> 8) & 1;
    uint32_t busy   = (status >> 7) & 1;
    uint32_t pred   = status & 0xF;

    printf("  Done: %u\n", done);
    printf("  Busy: %u\n", busy);
    printf("  Aguardando Peso (Wait_W): %u\n", wait_w);
    printf("  Predicao Atual: %u\n", pred);
}

void testar_dataset_diretorios(void* lw_virtual, int limite_por_classe, int *acertos_out, int *erros_hw_out, int *total_out, uint32_t *ciclos_out) {
    int acertos = 0, erros_hw = 0, total = 0;
    uint32_t soma_ciclos = 0;

    printf("\n>> Escaneando dataset nas pastas ./IMG/0 a ./IMG/9...\n");

    for (int label = 0; label < 10; label++) {
        char dir_path[256];
        snprintf(dir_path, sizeof(dir_path), "./IMG/%d", label);

        DIR *d = opendir(dir_path);
        if (!d) continue;

        struct dirent *dir;
        int count_classe = 0;

        while ((dir = readdir(d)) != NULL && count_classe < limite_por_classe) {
            if (strstr(dir->d_name, ".png") != NULL) {
                char img_path[512];
                snprintf(img_path, sizeof(img_path), "%s/%s", dir_path, dir->d_name);

                if (convert_png_to_raw(img_path, image_file) != 0) continue;

                if (enviar_imagem(lw_virtual) != 0) {
                    erros_hw++;
                    continue;
                }

                int32_t status = start_inf(lw_virtual);
                int32_t ciclos = get_cycles(lw_virtual);

                if (status >= 0) {
                    uint32_t pred_fpga = status & 0xF;
                    if (pred_fpga == (uint32_t)label) {
                        acertos++;
                    }
                    
                    soma_ciclos += ciclos;
                    total++;
                    count_classe++;
                } else {
                    erros_hw++;
                }
            }
        }
        closedir(d);
        printf("  - Classe [%d] processada: %d imagens.\n", label, count_classe);
    }

    *acertos_out = acertos;
    *erros_hw_out = erros_hw;
    *total_out = total;
    *ciclos_out = soma_ciclos;
}

/* ========================================================================= */
/* PROGRAMA PRINCIPAL                                                        */
/* ========================================================================= */

int main() {
    printf("\n--- ACELERADOR NEURAL ELM - START ---\n");

    void* lw_virtual = hps_open();
    if (lw_virtual == (void*)-1 || lw_virtual == NULL) {
        fprintf(stderr, "Erro fatal: Nao foi possivel mapear a memoria da FPGA.\n");
        return 1;
    }

    reset_cop(lw_virtual);

    int option;
    char filename[256];
    int32_t status, ciclos;

    while (1) {
        printf("\n==================================\n");
        printf("[0] Status do Coprocessador\n");
        printf("[1] Enviar Imagem\n");
        printf("[2] Enviar Bias (Manual)\n");
        printf("[3] Enviar Weights (Manual)\n");
        printf("[4] Enviar Beta (Manual)\n");
        printf("[5] Inferencia Simples\n");
        printf("[6] Inferencia de Estresse (100x)\n");
        printf("[7] Benchmark: Acuracia (Dataset)\n");
        printf("[8] Benchmark: Throughput\n");
        printf("[9] Configurar Funcao de Ativacao\n");
        printf("[10] Reset Hardware\n");
        printf("[11] Auto-Load: Carregar Rede Completa\n");
        printf("[12] Sair\n");
        printf("==================================\n");
        printf("=> ");
        
        if (scanf("%d", &option) != 1) {
            while (getchar() != '\n'); 
            continue;
        }

        switch (option) {
            case 0: {
                status = get_status(lw_virtual);
                printf("\nStatus Bruto: 0x%08X\n", status);
                show_status(status);
                
                uint32_t ativacao = (status >> 10) & 0x3;
                printf("  Ativacao Configurada: ");
                switch(ativacao) {
                    case 0: printf("0 (Tanh)\n"); break;
                    case 1: printf("1 (Sigmoide)\n"); break;
                    case 2: printf("2 (ReLU)\n"); break;
                    default: printf("%u (Desconhecida)\n", ativacao);
                }
                break;
            }

            case 1: {
                printf("Arquivo da imagem original (ex: img.png):\n=> ");
                if (scanf("%255s", filename) != 1) continue;

                if (convert_png_to_raw(filename, image_file) == 0) {
                    if (enviar_imagem(lw_virtual) == 0) {
                        printf(">> Imagem enviada com sucesso para a FPGA!\n");
                    } else {
                        printf(">> ERRO: Falha na transmissao HPS-FPGA.\n");
                    }
                }
                break;
            }

            case 2: {
                printf("Arquivo bias.mif: ");
                if (scanf("%255s", filename) != 1) continue;

                if (load_mif_to_u16(filename, buffer_bias, N_bias) == 0) {
                    save_u16_to_bin(bias_file, buffer_bias, N_bias);
                    if (enviar_bias(lw_virtual) == 0) printf(">> Bias enviado com sucesso!\n");
                    else printf(">> ERRO na transmissao.\n");
                }
                break;
            }

            case 3: {
                printf("Arquivo weights.mif: ");
                if (scanf("%255s", filename) != 1) continue;

                if (load_mif_to_u16(filename, buffer_weights, N_pesos) == 0) {
                    save_u16_to_bin(pesos_file, buffer_weights, N_pesos);
                    if (enviar_pesos(lw_virtual) == 0) printf(">> Pesos enviados com sucesso!\n");
                    else printf(">> ERRO na transmissao.\n");
                }
                break;
            }

            case 4: {
                printf("Arquivo beta.mif: ");
                if (scanf("%255s", filename) != 1) continue;

                if (load_mif_to_u16(filename, buffer_beta, N_beta) == 0) {
                    save_u16_to_bin(beta_file, buffer_beta, N_beta);
                    if (enviar_beta(lw_virtual) == 0) printf(">> Beta enviado com sucesso!\n");
                    else printf(">> ERRO na transmissao.\n");
                }
                break;
            }

            case 5: {
                printf("Disparando inferencia...\n");
                status = start_inf(lw_virtual); 
                ciclos = get_cycles(lw_virtual);

                if (status >= 0) {
                    printf(">> Inferencia OK | Pred: %u | %d ciclos de clock\n", status & 0xF, ciclos);
                } else {
                    printf(">> ERRO na inferencia (Codigo HW: %d)\n", status);
                }
                break;
            }

            case 6: {
                printf("Realizando 100 inferencias com a imagem atual na RAM...\n");
                int erros_hw = 0;
                uint32_t soma_c = 0;

                for (int i = 0; i < 100; i++) {
                    status = start_inf(lw_virtual);
                    ciclos = get_cycles(lw_virtual);

                    if (status >= 0) {
                        soma_c += ciclos;
                    } else {
                        erros_hw++;
                    }
                }
                printf("Concluido. Erros de hardware: %d | Media de ciclos: %.1f\n", erros_hw, (float)soma_c / (100 - erros_hw));
                break;
            }

            case 7: {
                printf("\n--- Teste de Acuracia do Modelo ---\n");
                int acertos = 0, erros_hw = 0, total_imagens = 0;
                uint32_t soma_ciclos = 0;

                testar_dataset_diretorios(lw_virtual, 100, &acertos, &erros_hw, &total_imagens, &soma_ciclos);

                if (total_imagens > 0) {
                    float acuracia = ((float)acertos / total_imagens) * 100.0f;
                    printf("\n>> RELATORIO: Imagens:%d | Acertos:%d | Erros HW:%d | ACURACIA: %.2f%%\n", 
                           total_imagens, acertos, erros_hw, acuracia);
                } else {
                    printf("Erro: Nenhuma imagem processada. Verifique as pastas ./IMG/\n");
                }
                break;
            }

            case 8: {
                printf("\n--- Teste de Throughput e Latencia ---\n");
                int acertos_t = 0, erros_hw_t = 0, total_imagens_t = 0;
                uint32_t soma_ciclos_t = 0;

                testar_dataset_diretorios(lw_virtual, 1000, &acertos_t, &erros_hw_t, &total_imagens_t, &soma_ciclos_t);

                if (total_imagens_t > 0) {
                    float media_ciclos = (float)soma_ciclos_t / total_imagens_t;
                    float tempo_por_img_us = (media_ciclos / 50.0f); // Considerando clock de 50MHz
                    
                    printf("\n>> RELATORIO: Latencia media: %.1f ciclos (%.2f us) | FPS estimado: %.0f\n", 
                           media_ciclos, tempo_por_img_us, 1000000.0f / tempo_por_img_us);
                }
                break;
            }

            case 9: {
                printf("Selecione a ativacao [0=Tanh, 1=Sigmoide, 2=ReLU]: ");
                int ativacao_escolhida;
                if (scanf("%d", &ativacao_escolhida) != 1) continue;

                if (ativacao_escolhida >= 0 && ativacao_escolhida <= 2) {
                    set_activation(lw_virtual, ativacao_escolhida);
                    printf(">> Funcao de ativacao atualizada no hardware!\n");
                } else {
                    printf(">> Opcao invalida.\n");
                }
                break;
            }

            case 10: {
                printf("Enviando sinal de Reset...\n");
                reset_cop(lw_virtual);
                break;
            }

            case 11: {
                printf("\n--- Carga Automatica de Parametros ---\n");
                status = get_status(lw_virtual);
                uint32_t ativacao_atual = (status >> 10) & 0x3;
                
                char base_path[256];
                if      (ativacao_atual == 0) snprintf(base_path, sizeof(base_path), "./Activations/Tanh");
                else if (ativacao_atual == 1) snprintf(base_path, sizeof(base_path), "./Activations/Sigm");
                else if (ativacao_atual == 2) snprintf(base_path, sizeof(base_path), "./Activations/Relu");
                else {
                    printf(">> ERRO: Funcao de ativacao desconhecida. Abortando carga.\n");
                    break;
                }

                printf(">> Carregando pesos da rede para o modo: %s\n", base_path);
                int erros_carga = 0;
                char filepath[512];

                // 1. Bias
                snprintf(filepath, sizeof(filepath), "%s/b_q.mif", base_path);
                if (load_mif_to_u16(filepath, buffer_bias, N_bias) == 0) {
                    save_u16_to_bin(bias_file, buffer_bias, N_bias);
                    if (enviar_bias(lw_virtual) != 0) erros_carga++;
                } else erros_carga++;

                // 2. Pesos
                snprintf(filepath, sizeof(filepath), "%s/W_in_q.mif", base_path);
                if (load_mif_to_u16(filepath, buffer_weights, N_pesos) == 0) {
                    save_u16_to_bin(pesos_file, buffer_weights, N_pesos);
                    if (enviar_pesos(lw_virtual) != 0) erros_carga++;
                } else erros_carga++;

                // 3. Beta
                snprintf(filepath, sizeof(filepath), "%s/beta_q.mif", base_path);
                if (load_mif_to_u16(filepath, buffer_beta, N_beta) == 0) {
                    save_u16_to_bin(beta_file, buffer_beta, N_beta);
                    if (enviar_beta(lw_virtual) != 0) erros_carga++;
                } else erros_carga++;

                if (erros_carga == 0) {
                    printf(">> Carga Concluida com Sucesso! FPGA pronta.\n");
                } else {
                    printf(">> ALERTA: Falha no carregamento. Rede corrompida!\n");
                }
                break;
            }

            case 12: {
                printf("Desmontando interface de hardware e encerrando...\n");
                hps_close(lw_virtual);
                return 0;
            }

            default:
                printf("Opcao invalida.\n");
        }
    }
    return 0;
}