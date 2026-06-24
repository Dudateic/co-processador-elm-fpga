#ifndef VGA_H
#define VGA_H

#include <stdint.h>

#define CELL_SIZE   8
#define CANVAS_PX   (28 * CELL_SIZE)
#define CANVAS_X    ((VGA_WIDTH  - CANVAS_PX) / 2)
#define CANVAS_Y    ((VGA_HEIGHT - CANVAS_PX) / 2)

#define VGA_WIDTH   320
#define VGA_HEIGHT  240

#define C_BLACK   0,0,0
#define C_GRAY    3,3,3
#define C_RED     3,2,3
#define C_BLUE    0,0,7

typedef struct {
    uint8_t cells[28][28];
    uint8_t old_cells[28][28];
} Canvas;

int vga_put_pixel_safe(volatile void *lw, uint16_t x, uint8_t y, uint8_t r, uint8_t g, uint8_t b);
int vga_fill_safe(volatile void *lw, uint8_t r, uint8_t g, uint8_t b);
int vga_fill_rect_safe(volatile void *lw, uint16_t x0, uint8_t y0, uint16_t w, uint8_t h, uint8_t r, uint8_t g, uint8_t b);
void ui_clear(volatile void *lw);


void canvas_clear(Canvas *c);
void canvas_clear_cell(Canvas *c, int gx, int gy);
void canvas_export(const Canvas *c);
void canvas_paint(Canvas *c, int gx, int gy);
void canvas_render(volatile void *lw, Canvas *c, int cur_gx, int cur_gy);
void exibir_imagem(uint32_t  *lw, uint8_t *buffer_image);

#endif