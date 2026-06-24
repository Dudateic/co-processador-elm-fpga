#ifndef PRINT_H
#define PRINT_H

void print_header(const char *title);
void print_separator(void);
void print_thin_sep(void);

void print_kv(const char *key, const char *value);
void print_kv_int(const char *key, long long value);
void print_kv_double(const char *key, double value, int precision);

void print_pred_header(void);
void print_pred_row(
    const char *tipo,
    const char *arquivo,
    int esperado,
    int previsto,
    int tempo_ms
);

#endif