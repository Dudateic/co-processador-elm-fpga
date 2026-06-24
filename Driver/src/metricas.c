#define _DEFAULT_SOURCE
#include "metricas.h"
#include "print.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <dirent.h>
#include <string.h>
#include <time.h>  
#include <sys/time.h>
#include "vga.h"
#include "mouse.h"
#include "api.h"
#include "converter.h"

#define CLOCK_FREQ 50000000.0
#define MAX_PASTAS 50
#define TAMANHO_NOME 256

#ifndef DT_DIR
#define DT_DIR 4
#endif

extern uint8_t buffer_image[784];

int matriz_confusao[10][10] = { {0} };


void gravar_log(const char *evento, const char *detalhe) {
    FILE *f_log = fopen("sistema.log", "a");
    if (!f_log) return;

    struct timeval tv;
    gettimeofday(&tv, NULL);
    
    struct tm *tm_info = localtime(&tv.tv_sec);
    
    char buffer_tempo[30];
    strftime(buffer_tempo, sizeof(buffer_tempo), "%Y-%m-%d %H:%M:%S", tm_info);

    fprintf(f_log, "[%s.%03ld] EVENTO: %-25s | %s\n", 
            buffer_tempo, tv.tv_usec / 1000, evento, detalhe);
    
    printf("[%s.%03ld] [LOG] %s: %s\n", 
           buffer_tempo, tv.tv_usec / 1000, evento, detalhe);

    fclose(f_log);
}


void show_status(uint32_t status) {
    uint32_t done     = (status >> 8) & 1;
    uint32_t busy     = (status >> 7) & 1;
    uint32_t pred     = status & 0xF;
    uint32_t ativacao = (status >> 10) & 0x3;

    print_header("Status do Coprocessador");
    print_kv_int   ("Done",         done);
    print_kv_int   ("Busy",         busy);
    print_kv_int   ("Predicao Atual", pred);
    print_kv("Ativacao",
        ativacao == 0 ? "Tanh" :
        ativacao == 1 ? "Sigmoide" :
        ativacao == 2 ? "ReLU" : "Desconhecida");
    print_separator();
}

double acuracia(int acertos, int total) {
    if (total == 0) return 0.0;
    return ((double)acertos * 100.0) / total;
}

double media_latencia(uint32_t *lat, int n) {
    if (n == 0) return 0.0;
    uint64_t soma = 0;
    for (int i = 0; i < n; i++) soma += lat[i];
    return (double)soma / n;
}

uint32_t min_latencia(uint32_t *lat, int n) {
    if (n <= 0) return 0;
    uint32_t m = lat[0];
    for (int i = 1; i < n; i++)
        if (lat[i] < m) m = lat[i];
    return m;
}

uint32_t max_latencia(uint32_t *lat, int n) {
    if (n <= 0) return 0;
    uint32_t m = lat[0];
    for (int i = 1; i < n; i++)
        if (lat[i] > m) m = lat[i];
    return m;
}

double desvio_padrao(uint32_t *lat, int n) {
    if (n <= 1) return 0.0;
    double med  = media_latencia(lat, n);
    double soma = 0.0;
    for (int i = 0; i < n; i++) {
        double d = (double)lat[i] - med;
        soma += d * d;
    }
    return sqrt(soma / n);
}

uint64_t total_ciclos(uint32_t *lat, int n) {
    uint64_t t = 0;
    for (int i = 0; i < n; i++) t += lat[i];
    return t;
}


void init_matriz(void) {
    for (int i = 0; i < NUM_CLASSES; i++)
        for (int j = 0; j < NUM_CLASSES; j++)
            matriz_confusao[i][j] = 0;
}

void atualizar_matriz(int real, int pred) {
    if (real >= 0 && real < NUM_CLASSES &&
        pred >= 0 && pred < NUM_CLASSES)
        matriz_confusao[real][pred]++;
}

void imprimir_matriz(void) {
    printf("\n  Matriz de Confusao (Linhas=Real, Colunas=Pred)\n");
    print_thin_sep();
    printf("     ");
    for (int j = 0; j < NUM_CLASSES; j++)
        printf("%5d", j);
    printf("\n");
    print_thin_sep();
    for (int i = 0; i < NUM_CLASSES; i++) {
        printf("  %d |", i);
        for (int j = 0; j < NUM_CLASSES; j++)
            printf("%5d", matriz_confusao[i][j]);
        printf("\n");
    }
    print_thin_sep();
}


int selecionar_diretorio_interativo(const char *diretorio_base, char *caminho_escolhido, size_t tamanho_buffer) {
    char caminho_atual[1024];
    
    strncpy(caminho_atual, diretorio_base, sizeof(caminho_atual) - 1);
    caminho_atual[sizeof(caminho_atual) - 1] = '\0';

    while (1) {
        DIR *d = opendir(caminho_atual);
        if (!d) {
            printf("\nErro: Nao foi possivel abrir o diretorio '%s'\n", caminho_atual);
            return 0; 
        }

        struct dirent *dir;
        char lista_pastas[MAX_PASTAS][TAMANHO_NOME];
        int qtd_pastas = 0;

        printf("\n==================================================\n");
        printf(" VOCE ESTA EM: %s\n", caminho_atual);
        printf("==================================================\n");
        printf("[ 0] *** ESCOLHER ESTA PASTA COMO O DATASET ***\n");
        printf("[-1] Cancelar e sair\n");
        printf("--------------------------------------------------\n");

        while ((dir = readdir(d)) != NULL) {
            // Ignora apenas o "." (diretório atual). 
            // Mantemos o ".." para que o usuário possa voltar uma pasta se entrar errado!
            if (strcmp(dir->d_name, ".") == 0) {
                continue;
            }

            if (dir->d_type == DT_DIR) {
                strncpy(lista_pastas[qtd_pastas], dir->d_name, TAMANHO_NOME - 1);
                lista_pastas[qtd_pastas][TAMANHO_NOME - 1] = '\0';
                
                printf("[%2d] Entrar em: %s/\n", qtd_pastas + 1, lista_pastas[qtd_pastas]);
                qtd_pastas++;

                if (qtd_pastas >= MAX_PASTAS) break;
            }
        }
        closedir(d);

        printf("\nEscolha uma opcao => ");

        int opcao;
        if (scanf("%d", &opcao) != 1) {
            while (getchar() != '\n'); // Limpa o buffer se o usuário digitar letras
            printf("Entrada invalida. Digite um numero.\n");
            continue; // Reinicia o loop
        }

        // Processa a escolha do usuário
        if (opcao == -1) {
            printf("Selecao cancelada.\n");
            return 0;
            
        } else if (opcao == 0) {
            // Usuário escolheu a pasta atual!
            strncpy(caminho_escolhido, caminho_atual, tamanho_buffer - 1);
            caminho_escolhido[tamanho_buffer - 1] = '\0';
            gravar_log("DIRETORIO_SELECIONADO", caminho_escolhido);
            printf("\n[+] Pasta definida com sucesso: %s\n", caminho_escolhido);
            return 1;
            
        } else if (opcao > 0 && opcao <= qtd_pastas) {
            // Usuário quer entrar em uma subpasta
            char temp_path[1024];
            snprintf(temp_path, sizeof(temp_path), "%s/%s", caminho_atual, lista_pastas[opcao - 1]);
            
            // Atualiza o caminho atual e o loop roda novamente para mostrar a nova pasta
            strncpy(caminho_atual, temp_path, sizeof(caminho_atual) - 1);
            caminho_atual[sizeof(caminho_atual) - 1] = '\0';
            
        } else {
            printf("Opcao invalida. Tente novamente.\n");
        }
    }
}

int testar_diretorio(void *lw, const char *pasta_base, int limite, int label,
                                 DatasetTest *t, AmostraDetalhe *detalhes, int *n_det) {

    int acertos = 0, erros = 0, total = 0;
    uint64_t soma_ciclos = 0;
    int idx = 0;
    int det_idx = 0;

    char path[512];
    snprintf(path, sizeof(path), "%s/%d", pasta_base, label);

    DIR *d = opendir(path);
    if (!d) {
        char msg_erro[512];
        snprintf(msg_erro, sizeof(msg_erro), "Falha ao abrir subpasta: %s", path);
        gravar_log("ERRO_ABERTURA_PASTA", msg_erro);
        return -1;
    }

    char msg_pasta[512];
    snprintf(msg_pasta, sizeof(msg_pasta), "Iniciando processamento da pasta: %s", path);
    gravar_log("ABRIU_SUBPASTA", msg_pasta);

    struct dirent *dir;
    char log_buf[512]; 

    while ((dir = readdir(d)) != NULL && (limite <= 0 || total < limite)) {
        if (strstr(dir->d_name, ".png") == NULL)
            continue;

        char img[512];
        snprintf(img, sizeof(img), "%s/%s", path, dir->d_name);

        if (convert_png_to_raw(img, buffer_image, sizeof(buffer_image)) != 0)
            continue;

        exibir_imagem(lw, buffer_image);

        snprintf(log_buf, sizeof(log_buf), "Enviando arquivo '%s' para a FPGA", dir->d_name);
        gravar_log("ENVIANDO_IMAGEM", log_buf);

        if (enviar_imagem(lw, buffer_image) != 0) {
            snprintf(log_buf, sizeof(log_buf), "Falha ao enviar '%s'", dir->d_name);
            gravar_log("ERRO_ENVIO_FPGA", log_buf);
            erros++;
            continue;
        }

        gravar_log("START_INFERENCIA", "Sinal de START enviado ao coprocessador");
        
        int32_t status = start_inf(lw);
        int32_t ciclos = get_cycles(lw);

        if (status >= 0) {
            uint32_t pred = status & 0xF;

            snprintf(log_buf, sizeof(log_buf), 
                     "Resultado recebido de '%s' -> Predicao: %u | Ciclos HW: %d", 
                     dir->d_name, pred, ciclos);
            gravar_log("RESULTADO_RECEBIDO", log_buf);

            if (idx < MAX_AMOSTRAS)
                t->latencias[idx++] = (uint32_t)ciclos;

            if (detalhes != NULL && n_det != NULL && det_idx < (MAX_AMOSTRAS * NUM_CLASSES)) {
                AmostraDetalhe *a = &detalhes[det_idx++];
                snprintf(a->pasta, sizeof(a->pasta), "%s/%d", pasta_base, label);
                snprintf(a->arquivo, sizeof(a->arquivo), "%s", dir->d_name);
                a->label_real = label;
                a->pred       = (int)pred;
                a->ciclos     = (uint32_t)ciclos;
            }

            if (pred == (uint32_t)label)
                acertos++;

            atualizar_matriz(label, (int)pred);
            soma_ciclos += (uint32_t)ciclos;
            total++;
        } else {
            snprintf(log_buf, sizeof(log_buf), "Hardware travou ou retornou erro para '%s'", dir->d_name);
            gravar_log("ERRO_INFERENCIA_HW", log_buf);
            erros++;
        }
    }

    closedir(d);
    
    snprintf(log_buf, sizeof(log_buf), "Fim da pasta %s. Processadas: %d, Erros: %d", path, total, erros);
    gravar_log("FECHOU_SUBPASTA", log_buf);

    t->acertos  = acertos;
    t->erros_hw = erros;
    t->total    = total;
    t->ciclos   = soma_ciclos;

    if (n_det != NULL) *n_det = det_idx;

    return idx;
}

void executar_benchmark_completo(void *lw, int limite_por_classe, const char *prefixo) {
    char pasta_dataset[512];
    if (!selecionar_diretorio_interativo(".", pasta_dataset, sizeof(pasta_dataset))) {
        printf("Benchmark abortado pelo usuario.\n");
        return;
    }

    static uint32_t      todas_latencias[MAX_AMOSTRAS * NUM_CLASSES];
    static AmostraDetalhe todos_detalhes [MAX_AMOSTRAS * NUM_CLASSES];

    int total_lat  = 0;
    int total_det  = 0;
    int acertos_globais = 0;
    int erros_globais   = 0;
    int total_global    = 0;

    int acertos_por_classe [NUM_CLASSES] = {0};
    int total_por_classe   [NUM_CLASSES] = {0};

    double  media_lat_classe[NUM_CLASSES] = {0.0};
    uint32_t min_lat_classe [NUM_CLASSES] = {0};
    uint32_t max_lat_classe [NUM_CLASSES] = {0};

    init_matriz();

    for (int label = 0; label < NUM_CLASSES; label++) {
        DatasetTest tc;
        memset(&tc, 0, sizeof(DatasetTest));

        AmostraDetalhe *det_inicio = &todos_detalhes[total_det];
        int n_det_classe = 0;

        printf("Testando classe [%d] na pasta %s/%d...\n", label, pasta_dataset, label);
        fflush(stdout);

        int qtd_lat = testar_diretorio(lw, pasta_dataset, limite_por_classe, label,
                                                  &tc, det_inicio, &n_det_classe);

        if (qtd_lat <= 0) {
            printf("ERRO: Diretorio %s/%d nao encontrado ou vazio.\n", pasta_dataset, label);
            continue;
        }

        for (int i = 0; i < qtd_lat && total_lat < (MAX_AMOSTRAS * NUM_CLASSES); i++)
            todas_latencias[total_lat++] = tc.latencias[i];

        total_det += n_det_classe;
        acertos_globais += tc.acertos;
        erros_globais   += tc.erros_hw;
        total_global    += tc.total;

        acertos_por_classe[label] = tc.acertos;
        total_por_classe  [label] = tc.total;

        if (qtd_lat > 0) {
            media_lat_classe[label] = media_latencia(tc.latencias, qtd_lat);
            min_lat_classe  [label] = min_latencia  (tc.latencias, qtd_lat);
            max_lat_classe  [label] = max_latencia  (tc.latencias, qtd_lat);
        }

        double acc_c = acuracia(tc.acertos, tc.total);
        printf("Total: %d | Acertos: %d | Acuracia: %.2f%%\n", tc.total, tc.acertos, acc_c);
    }

    double   acc_global  = acuracia     (acertos_globais, total_global);
    double   med_lat     = media_latencia(todas_latencias, total_lat);
    uint32_t min_lat     = (total_lat > 0) ? min_latencia(todas_latencias, total_lat) : 0;
    uint32_t max_lat     = (total_lat > 0) ? max_latencia(todas_latencias, total_lat) : 0;
    double   desvio_lat  = desvio_padrao (todas_latencias, total_lat);
    uint64_t ciclos_tot  = total_ciclos  (todas_latencias, total_lat);

    double throughput_por_ciclo = (ciclos_tot > 0) ? ((double)total_global / (double)ciclos_tot) : 0.0;
    double throughput_por_segundo = throughput_por_ciclo * CLOCK_FREQ;

    print_header("RESULTADOS GLOBAIS");
    print_kv_int   ("Total de Imagens Processadas", total_global);
    print_kv_int   ("Total de Erros de Hardware",   erros_globais);
    print_kv_double("Acuracia Global (%)",           acc_global,  2);
    print_kv_double("Throughput (img/ciclo)",        throughput_por_ciclo,  6);
    print_kv_double("Latencia Media (Ciclos)",       med_lat,     2);
    print_kv_int   ("Latencia Minima (Ciclos)",      (long long)min_lat);
    print_kv_int   ("Latencia Maxima (Ciclos)",      (long long)max_lat);
    print_kv_double("Desvio Padrao (Ciclos)",        desvio_lat,  2);
    print_kv_int   ("Total de Ciclos Gastos",        (long long)ciclos_tot);
    print_separator();

    imprimir_matriz();

    char fname[512];
    snprintf(fname, sizeof(fname), "%s_metricas.csv", prefixo);
    FILE *f1 = fopen(fname, "w");
    if (f1) {
        fprintf(f1, "Metrica,Valor\n");
        fprintf(f1, "Total Imagens Processadas,%d\n",          total_global);
        fprintf(f1, "Total Erros Hardware,%d\n",               erros_globais);
        fprintf(f1, "Acuracia Global (%%),%0.2f\n",             acc_global);
        fprintf(f1, "Throughput (img/ciclo),%.6f\n",           throughput_por_ciclo);
        fprintf(f1, "Latencia Media (Ciclos),%.2f\n",          med_lat);
        fprintf(f1, "Latencia Minima (Ciclos),%u\n",           min_lat);
        fprintf(f1, "Latencia Maxima (Ciclos),%u\n",           max_lat);
        fprintf(f1, "Desvio Padrao (Ciclos),%.2f\n",           desvio_lat);
        fprintf(f1, "Total de Ciclos,%llu\n", (unsigned long long)ciclos_tot);
        fclose(f1);
        printf("[OK] %s\n", fname);
    }

    snprintf(fname, sizeof(fname), "%s_por_digito.csv", prefixo);
    FILE *f2 = fopen(fname, "w");
    if (f2) {
        fprintf(f2, "Digito,Total,Acertos,Erros,Acuracia(%%),Lat_Media,Lat_Min,Lat_Max\n");
        for (int i = 0; i < NUM_CLASSES; i++) {
            double acc = acuracia(acertos_por_classe[i], total_por_classe[i]);
            int erros_c = total_por_classe[i] - acertos_por_classe[i];
            fprintf(f2, "%d,%d,%d,%d,%.2f,%.2f,%u,%u\n", i, total_por_classe[i], acertos_por_classe[i], erros_c, acc, media_lat_classe[i], min_lat_classe[i], max_lat_classe[i]);
        }
        fclose(f2);
        printf("[OK] %s\n", fname);
    }

    snprintf(fname, sizeof(fname), "%s_confusao.csv", prefixo);
    FILE *f3 = fopen(fname, "w");
    if (f3) {
        fprintf(f3, "Real/Pred");
        for (int j = 0; j < NUM_CLASSES; j++) fprintf(f3, ",%d", j);
        fprintf(f3, "\n");
        for (int i = 0; i < NUM_CLASSES; i++) {
            fprintf(f3, "%d", i);
            for (int j = 0; j < NUM_CLASSES; j++) fprintf(f3, ",%d", matriz_confusao[i][j]);
            fprintf(f3, "\n");
        }
        fclose(f3);
        printf("[OK] %s\n", fname);
    }

    snprintf(fname, sizeof(fname), "%s_detalhes.csv", prefixo);
    FILE *f4 = fopen(fname, "w");
    if (f4) {
        fprintf(f4, "Pasta,Arquivo,Label_Real,Predicao,Correto,Ciclos\n");
        for (int i = 0; i < total_det; i++) {
            AmostraDetalhe *a = &todos_detalhes[i];
            fprintf(f4, "%s,%s,%d,%d,%s,%u\n", a->pasta, a->arquivo, a->label_real, a->pred, (a->label_real == a->pred) ? "SIM" : "NAO", a->ciclos);
        }
        fclose(f4);
        printf("[OK] %s\n", fname);
    }

    print_separator();
    printf("Relatorios salvos com prefixo: %s\n", prefixo);
    print_separator();
}