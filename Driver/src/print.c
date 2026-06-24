#ifndef PRINT_H
#define PRINT_H

#include <stdio.h>
#include <string.h>

#define LINE_WIDTH 75


void print_line(char c, int width) {
    for (int i = 0; i < width; i++)
        putchar(c);
    putchar('\n');
}

void print_separator(void) {
    print_line('=', LINE_WIDTH);
}

void print_thin_sep(void) {
    print_line('-', LINE_WIDTH);
}

void print_center(const char *text) {
    int len = (int)strlen(text);
    if (len >= LINE_WIDTH) {
        printf("%s\n", text);
        return;
    }
    int padding = (LINE_WIDTH - len) / 2;
    for (int i = 0; i < padding; i++)
        putchar(' ');
    printf("%s\n", text);
}

void print_header(const char *title) {
    print_separator();
    print_center(title);
    print_separator();
}


void print_kv(const char *key, const char *value) {
    int key_len   = (int)strlen(key);
    int value_len = (int)strlen(value);
    int dots      = LINE_WIDTH - 4 - key_len - 3 - value_len;
    if (dots < 1) dots = 1;
    printf("  %s ", key);
    for (int i = 0; i < dots; i++) putchar('.');
    printf(" : %s\n", value);
}

void print_kv_int(const char *key, long long value) {
    char buf[32];
    snprintf(buf, sizeof(buf), "%lld", value);
    print_kv(key, buf);
}

void print_kv_double(const char *key, double value, int decimals) {
    char fmt[16], buf[32];
    snprintf(fmt, sizeof(fmt), "%%.%df", decimals);
    snprintf(buf, sizeof(buf), fmt, value);
    print_kv(key, buf);
}

/*
Cabeçalho da tabela de predições individuais:
Pasta  |  Arquivo  |  Real  |  Pred  |  OK?  |  Ciclos
*/
void print_pred_header(void) {
    print_thin_sep();
    printf("%-20s %-30s  Real  Pred  OK?  Ciclos\n",
           "Pasta", "Arquivo");
    print_thin_sep();
}

void print_pred_row(const char *pasta,
                                   const char *arquivo,
                                   int real,
                                   int pred,
                                   unsigned int ciclos) {
    printf("%-20s %-30s  %4d  %4d   %s   %u\n",
           pasta, arquivo, real, pred,
           (real == pred) ? "OK " : "ERR",
           ciclos);
}

#endif /* PRINT_H */