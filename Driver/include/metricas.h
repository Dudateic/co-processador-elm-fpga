#ifndef METRICAS_H
#define METRICAS_H

#include <stdint.h>
#include <stdio.h>

#define NUM_CLASSES  10
#define MAX_AMOSTRAS 1000

typedef struct {
    int      acertos;
    int      erros_hw;
    int      total;
    uint64_t ciclos;
    uint32_t latencias[MAX_AMOSTRAS];
} DatasetTest;


typedef struct {
    char     pasta[64];
    char     arquivo[128];
    int      label_real;
    int      pred;
    uint32_t ciclos;
} AmostraDetalhe;

void     show_status       (uint32_t status);

double   acuracia          (int acertos, int total);
double   media_latencia    (uint32_t *lat, int n);
uint32_t min_latencia      (uint32_t *lat, int n);
uint32_t max_latencia      (uint32_t *lat, int n);
double   desvio_padrao     (uint32_t *lat, int n);
uint64_t total_ciclos      (uint32_t *lat, int n);

void     init_matriz       (void);
void     atualizar_matriz  (int real, int pred);
void     imprimir_matriz   (void);

/*
 * testar_diretorio agora recebe também:
 *   detalhes  – vetor para registros individuais (pode ser NULL)
 *   n_det     – ponteiro para quantidade preenchida (pode ser NULL)
 */
int  testar_diretorio(void *lw, const char *pasta_base, int limite, int label,
                                 DatasetTest *t, AmostraDetalhe *detalhes, int *n_det);

/*
 * Benchmark completo: gera 4 CSVs separados.
 *   prefixo  – ex: "resultado"  →  resultado_metricas.csv
 *                                   resultado_por_digito.csv
 *                                   resultado_confusao.csv
 *                                   resultado_detalhes.csv
 */
void executar_benchmark_completo(void *lw,
                                  int limite_por_classe,
                                  const char *prefixo);

#endif /* METRICAS_H */