#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <dirent.h>
#include <stdbool.h>
#include <fcntl.h>
#include <unistd.h>

#include "api.h"
#include "hps_0.h"
#include "buffers.h"
#include "converter.h"
#include "metricas.h"
#include "print.h"
#include "vga.h"
#include "mouse.h"

extern uint8_t  buffer_image[784];
extern uint16_t buffer_bias[128];
extern uint16_t buffer_beta[1280];
extern uint16_t buffer_weights[100352];


static int ler_caminho(char *path) {
    printf("Caminho: => ");
    return (scanf("%255s", path) == 1);
}

static int carregar_e_enviar(
    void *lw,
    const char *nome,
    const char *path,
    void *buffer,
    uint32_t n,
    int (*loader)(const char*, uint16_t*, uint32_t),
    int (*sender)(void*, uint16_t*)
) {
    printf("Carregando %s...\n", nome);
    if (loader(path, buffer, n) != 0) {
        printf("Erro ao carregar %s\n", nome);
        return -1;
    }
    if (sender(lw, buffer) != 0) {
        printf("Erro ao enviar %s para FPGA\n", nome);
        return -2;
    }
    printf("%s carregado com sucesso!\n", nome);
    return 0;
}


static void auto_load(void *lw) {
    int32_t  status    = get_status(lw);
    uint32_t ativ      = (status >> 10) & 0x3;
    char     base[256];

    if      (ativ == 0) snprintf(base, sizeof(base), "./Activations/Tanh");
    else if (ativ == 1) snprintf(base, sizeof(base), "./Activations/Sigm");
    else if (ativ == 2) snprintf(base, sizeof(base), "./Activations/Relu");
    else { print_header("ERRO: Ativacao desconhecida."); return; }

    printf("Carregando: %s\n", base);

    int erros = 0;
    char fp[512];

    snprintf(fp, sizeof(fp), "%s/b_q.mif",    base);
    if (load_mif_to_u16(fp, buffer_bias,    N_bias)  == 0) {
        if (enviar_bias(lw, buffer_bias)   != 0) erros++;
    } else erros++;

    snprintf(fp, sizeof(fp), "%s/W_in_q.mif", base);
    if (load_mif_to_u16(fp, buffer_weights, N_pesos) == 0) {
        if (enviar_pesos(lw, buffer_weights) != 0) erros++;
    } else erros++;

    snprintf(fp, sizeof(fp), "%s/beta_q.mif", base);
    if (load_mif_to_u16(fp, buffer_beta,    N_beta)  == 0) {
        if (enviar_beta(lw, buffer_beta)   != 0) erros++;
    } else erros++;

    print_header(erros == 0 ? "Carga Concluida com Sucesso!"
                            : "ALERTA: Falha no carregamento!");
}


static void menu_configuracao(void *lw) {
    int op;
    char filename[256];

    while (1) {
        print_header("Configuracao");
        printf("[1] Carregar bias\n");
        printf("[2] Carregar weights\n");
        printf("[3] Carregar beta\n");
        printf("[4] Auto-Load\n");
        printf("[5] Selecionar Ativacao\n");
        printf("[0] Voltar\n");
        printf("=> ");

        if (scanf("%d", &op) != 1) return;

        switch (op) {
            case 1:
                if (ler_caminho(filename))
                    carregar_e_enviar(lw, "bias", filename,
                                      buffer_bias, N_bias,
                                      load_mif_to_u16, enviar_bias);
                break;
            case 2:
                if (ler_caminho(filename))
                    carregar_e_enviar(lw, "weights", filename,
                                      buffer_weights, N_pesos,
                                      load_mif_to_u16, enviar_pesos);
                break;
            case 3:
                if (ler_caminho(filename))
                    carregar_e_enviar(lw, "beta", filename,
                                      buffer_beta, N_beta,
                                      load_mif_to_u16, enviar_beta);
                break;
            case 4:
                auto_load(lw);
                break;
            case 5: {
                int ativ;
                print_header("[0] Tanh  [1] Sigm  [2] ReLU");
                printf("=> ");
                if (scanf("%d", &ativ) != 1) return;
                set_activation(lw, ativ);
                break;
            }
            case 0: return;
            default: printf("Opcao invalida!\n");
        }
    }
}


static void menu_inferencia(void *lw) {
    int op;
    char path[256];

    while (1) {
        print_header("Inferencia");
        printf("[1] Desenhar Imagem\n");
        printf("[2] Caminho da Imagem\n");
        printf("[3] Caminho da Pasta\n");
        printf("[0] Voltar\n");
        printf("=> ");

        if (scanf("%d", &op) != 1) { while (getchar() != '\n'); continue; }

        switch (op) {
            case 1:
                auto_load(lw);
                modo_desenho(lw);
                break;

            case 2:
                if (!ler_caminho(path)) { print_header("Erro ao ler caminho!"); break; }
                if (convert_png_to_raw(path, buffer_image, sizeof(buffer_image)) == 0) {
                    enviar_imagem(lw, buffer_image);
                    exibir_imagem(lw, buffer_image);
                    start_inf(lw);
                } else {
                    print_header("Erro ao carregar imagem.");
                }
                break;

            case 3: {
                int label, limite;

                printf("Classe (0-9): => ");
                if (scanf("%d", &label)  != 1) return;
                printf("Limite (0=todas): => ");
                if (scanf("%d", &limite) != 1) return;
                DatasetTest t;
                memset(&t, 0, sizeof(DatasetTest));

                int qtd = testar_diretorio(lw, "IMG", limite, label, &t, NULL, NULL);
                if (qtd < 0) { print_header("Erro ao acessar dataset!"); break; }

                if (t.total > MAX_AMOSTRAS) t.total = MAX_AMOSTRAS;

                print_header("Resultado da Inferencia");
                printf("Acertos  : %d\n",   t.acertos);
                printf("Erros HW : %d\n",   t.erros_hw);
                printf("Total    : %d\n",   t.total);
                printf("Acuracia : %.2f%%\n", acuracia(t.acertos, t.total));
                print_separator();
                break;
            }

            case 0: return;
            default: printf("Opcao invalida!\n");
        }
    }
}


static void menu_benchmark(void *lw) {
    int op;
    while (1) {
        print_header("BENCHMARK");
        printf("[1] Acuracia\n");
        printf("[2] Throughput\n");
        printf("[3] Latencia\n");
        printf("[4] Desvio padrao\n");
        printf("[5] Matriz de confusao (classe)\n");
        printf("[6] Matriz de confusao (todas as classes)\n");
        printf("[7] Teste Completo + 4 CSVs\n");
        printf("[0] Voltar\n");
        printf("=> ");
        char caminho_dataset[1024] = "";
        if (scanf("%d", &op) != 1) { while (getchar() != '\n'); continue; }
        if (op == 0) return;

        int label = 0, limite = 0;
        DatasetTest t;
        memset(&t, 0, sizeof(DatasetTest));

        if (op >= 1 && op <= 4) {
            if (caminho_dataset[0] == '\0') {
                printf("\n[!] AVISO: Nenhum dataset selecionado!\n");
                printf("Por favor, selecione o diretorio do dataset primeiro.\n");
                
                if (!selecionar_diretorio_interativo(".", caminho_dataset, sizeof(caminho_dataset))) {
                    continue; 
                }
            }
            printf("Classe (0-9): => ");
            if (scanf("%d", &label)  != 1) continue;
            printf("Limite (0=todas): => ");
            if (scanf("%d", &limite) != 1) continue;

            int qtd = testar_diretorio(lw, caminho_dataset, limite, label, &t, NULL, NULL);
            if (qtd <= 0) { printf("Nenhuma imagem processada!\n"); continue; }
        }

        switch (op) {
            case 1:
                print_header("Acuracia");
                printf("Acuracia: %.2f%%\n", acuracia(t.acertos, t.total));
                break;

            case 2:
                print_header("Throughput");
                if (t.ciclos > 0)
                    printf("Throughput: %.6f img/ciclo\n",
                           (double)t.total / (double)t.ciclos);
                else
                    printf("Sem ciclos validos.\n");
                break;

            case 3:
                print_header("Latencia");
                printf("Latencia Media  : %.2f ciclos\n",
                       media_latencia(t.latencias, t.total));
                printf("Latencia Minima : %u ciclos\n",
                       min_latencia(t.latencias, t.total));
                printf("Latencia Maxima : %u ciclos\n",
                       max_latencia(t.latencias, t.total));
                printf("Latencia Total  : %llu ciclos\n",
                       (unsigned long long)total_ciclos(t.latencias, t.total));
                break;

            case 4:
                print_header("Desvio Padrao");
                printf("Desvio Padrao: %.2f ciclos\n",
                       desvio_padrao(t.latencias, t.total));
                break;

            case 5:
                print_header("Matriz de Confusao");
                imprimir_matriz();
                break;

            case 6: {
                print_header("Matriz de Confusao — Todas as Classes");
                init_matriz();
                for (int i = 0; i < NUM_CLASSES; i++) {
                    DatasetTest tc;
                    memset(&tc, 0, sizeof(DatasetTest));
                    testar_diretorio(lw, "/IMG", 100, i, &tc, NULL, NULL);
                }
                imprimir_matriz();
                break;
            }

            case 7: {
                char prefixo[256];
                int  lim;

                printf("Prefixo do arquivo (ex: resultado): => ");
                if (scanf("%255s", prefixo) != 1) break;
                printf("Limite por classe (0=todas): => ");
                if (scanf("%d", &lim) != 1) break;

                executar_benchmark_completo(lw, lim, prefixo);
                break;
            }

            default:
                printf("Opcao invalida!\n");
        }
    }
}


int main(void) {
    print_header("Acelerador Neural ELM");

    void *lw = hps_open();
    if (lw == (void *)-1 || lw == NULL) {
        fprintf(stderr, "Erro fatal: Nao foi possivel mapear a memoria da FPGA.\n");
        return 1;
    }

    reset_cop(lw);

    int op;
    while (1) {
        print_header("Menu Principal");
        printf("[1] Configuracao\n");
        printf("[2] Inferencia\n");
        printf("[3] Benchmark\n");
        printf("[4] Status\n");
        printf("[0] Sair\n");
        printf("=> ");
        print_separator();

        if (scanf("%d", &op) != 1) break;

        switch (op) {
            case 1: menu_configuracao(lw); break;
            case 2: menu_inferencia(lw);   break;
            case 3: menu_benchmark(lw);    break;
            case 4: show_status(get_status(lw)); break;
            case 0: printf("Encerrando...\n"); hps_close(lw); return 0;
            default: printf("Opcao invalida!\n");
        }
    }

    hps_close(lw);
    return 0;
}