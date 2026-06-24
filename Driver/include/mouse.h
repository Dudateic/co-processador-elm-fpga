#ifndef MOUSE_H
#define MOUSE_H

#include <stdint.h>


void modo_desenho(void *lw_void);

int salvar_buffer_png(const char *arquivo, uint8_t * buffer_image);

#endif // MOUSE_H