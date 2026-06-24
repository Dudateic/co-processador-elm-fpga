#include "vga.h"
#include "buffers.h"
#include "hps_0.h"
#include <string.h>
#include <stdlib.h>

#define BRUSH_RADIUS  1

static int last_cur_gx = -1;
static int last_cur_gy = -1;

void exibir_imagem(uint32_t* lw, uint8_t *buffer) {
    for (int y = 0; y < 28; y++) {
        for (int x = 0; x < 28; x++) {
            int index = (y * 28) + x;
            uint8_t pixel_val = buffer[index];

            uint8_t brilho = (uint8_t)((pixel_val * 7) / 255);

            int tela_x = CANVAS_X + x * CELL_SIZE;
            int tela_y = CANVAS_Y + y * CELL_SIZE;

            vga_fill_rect_safe(lw, 
                            tela_x, tela_y,          
                            CELL_SIZE, CELL_SIZE,    
                            brilho, brilho, brilho);
        }
    }
}

int vga_put_pixel_safe(volatile void *lw, uint16_t x, uint8_t y, uint8_t r, uint8_t g, uint8_t b) {
    volatile uint32_t *pixel = (volatile uint32_t *)((uint8_t *)lw + VGA_PIXEL);
    volatile uint32_t *en    = (volatile uint32_t *)((uint8_t *)lw + VGA_ENABLE);

    uint32_t word =
        (x & 0x1FF)
        | ((y & 0xFF) << 9)
        | ((r & 0x7) << 17)
        | ((g & 0x7) << 20)
        | ((b & 0x7) << 23);

    *pixel = word;
    *en = 1;
    return 0;
}

int vga_fill_safe(volatile void *lw, uint8_t r, uint8_t g, uint8_t b) {
    for (int y = 0; y < VGA_HEIGHT; y++)
        for (int x = 0; x < VGA_WIDTH; x++)
            vga_put_pixel_safe(lw, x, y, r, g, b);
    return 0;
}

int vga_fill_rect_safe(volatile void *lw, uint16_t x0, uint8_t y0, uint16_t w, uint8_t h, uint8_t r, uint8_t g, uint8_t b) {
    for (int dy = 0; dy < h; dy++)
        for (int dx = 0; dx < w; dx++)
            vga_put_pixel_safe(lw, x0 + dx, y0 + dy, r, g, b);
    return 0;
}

void ui_clear(volatile void *lw) {
    vga_fill_rect_safe(lw, 0, 0, VGA_WIDTH, VGA_HEIGHT, C_BLACK);
    last_cur_gx = -1;
    last_cur_gy = -1;
}

void canvas_clear(Canvas *c) {
    memset(c->cells, 0, sizeof(c->cells));
}

void canvas_clear_cell(Canvas *c, int gx, int gy) {
    if (gx >= 0 && gx < 28 && gy >= 0 && gy < 28)
        c->cells[gy][gx] = 0;
}

void canvas_export(const Canvas *c) {
    for (int y = 0; y < 28; y++)
        for (int x = 0; x < 28; x++)
            buffer_image[y * 28 + x] = c->cells[y][x];
}
void canvas_paint(Canvas *c, int gx, int gy) {
   
    const uint8_t incremento_gaussiano[3][3] = {
        {5,  25,  5},
        {25, 50, 25},
        {5,  25,  5}
    };

    for (int dy = -BRUSH_RADIUS; dy <= BRUSH_RADIUS; dy++) {
        for (int dx = -BRUSH_RADIUS; dx <= BRUSH_RADIUS; dx++) {
            int nx = gx + dx;
            int ny = gy + dy;

            if (nx >= 0 && nx < 28 && ny >= 0 && ny < 28) {
                
                uint8_t inc = incremento_gaussiano[dy + 1][dx + 1];

                if ((int)c->cells[ny][nx] + inc > 255) {
                    c->cells[ny][nx] = 255; 
                } else {
                    c->cells[ny][nx] += inc;
                }
            }
        }
    }
}

void canvas_render(volatile void *lw, Canvas *c, int cur_gx, int cur_gy) {
    
    if (last_cur_gx >= 0 && last_cur_gy >= 0 && (last_cur_gx != cur_gx || last_cur_gy != cur_gy)) {
        c->old_cells[last_cur_gy][last_cur_gx] = 256; 
    }

    for (int y = 0; y < 28; y++) {
        for (int x = 0; x < 28; x++) {
            uint8_t current_val = c->cells[y][x];
            
            if (current_val != c->old_cells[y][x]) {
                uint8_t b = (uint8_t)((current_val * 7) / 255);
                
                vga_fill_rect_safe(
                    lw,
                    CANVAS_X + x * CELL_SIZE,
                    CANVAS_Y + y * CELL_SIZE,
                    CELL_SIZE, CELL_SIZE,
                    b, b, b
                );
                c->old_cells[y][x] = current_val;
            }
        }
    }

    if (last_cur_gx >= 0 && last_cur_gy >= 0 && (last_cur_gx != cur_gx || last_cur_gy != cur_gy)) {
        uint8_t val_antigo = c->cells[last_cur_gy][last_cur_gx];
        uint8_t b_antigo = (uint8_t)((val_antigo * 7) / 255);
        vga_fill_rect_safe(
            lw,
            CANVAS_X + last_cur_gx * CELL_SIZE,
            CANVAS_Y + last_cur_gy * CELL_SIZE,
            CELL_SIZE, CELL_SIZE,
            b_antigo, b_antigo, b_antigo
        );
        
        vga_put_pixel_safe(lw, CANVAS_X + last_cur_gx * CELL_SIZE, CANVAS_Y, C_GRAY);
        vga_put_pixel_safe(lw, CANVAS_X, CANVAS_Y + last_cur_gy * CELL_SIZE, C_GRAY);
    }

    if (last_cur_gx == -1) {
        for (int i = 0; i <= 28; i++) {
            vga_put_pixel_safe(lw, CANVAS_X + i * CELL_SIZE, CANVAS_Y, C_GRAY);
            vga_put_pixel_safe(lw, CANVAS_X, CANVAS_Y + i * CELL_SIZE, C_GRAY);
        }
    }
    if (cur_gx >= 0 && cur_gx < 28 && cur_gy >= 0 && cur_gy < 28) {
        vga_fill_rect_safe(
            lw,
            CANVAS_X + cur_gx * CELL_SIZE,
            CANVAS_Y + cur_gy * CELL_SIZE,
            CELL_SIZE, CELL_SIZE,
            C_RED
        );
        
        c->old_cells[cur_gy][cur_gx] = 256; 

        last_cur_gx = cur_gx;
        last_cur_gy = cur_gy;
    }
}


/*
void canvas_render(volatile void *lw, Canvas *c, int cur_gx, int cur_gy) {
    
    if (last_cur_gx >= 0 && last_cur_gy >= 0 && (last_cur_gx != cur_gx || last_cur_gy != cur_gy)) {

        c->old_cells[last_cur_gy][last_cur_gx] = 256; 
    }

    // 2. Renderiza apenas as células que mudaram de estado (ou foram invalidadas acima)
    for (int y = 0; y < 28; y++) {
        for (int x = 0; x < 28; x++) {
            uint8_t current_val = c->cells[y][x];
            
            if ((int)current_val != c->old_cells[y][x]) {
                uint8_t b = (uint8_t)((current_val * 7) / 255);
                
                vga_fill_rect_safe(
                    lw,
                    CANVAS_X + x * CELL_SIZE,
                    CANVAS_Y + y * CELL_SIZE,
                    CELL_SIZE, CELL_SIZE,
                    b, b, b
                );
                c->old_cells[y][x] = (int)current_val;
            }
        }
    }

    // 3. Desenha as bordas iniciais (se necessário)
    if (last_cur_gx == -1) {
        for (int i = 0; i <= 28; i++) {
            vga_put_pixel_safe(lw, CANVAS_X + i * CELL_SIZE, CANVAS_Y, C_GRAY);
            vga_put_pixel_safe(lw, CANVAS_X, CANVAS_Y + i * CELL_SIZE, C_GRAY);
        }
    }

    // 4. Desenha o cursor vermelho na posição ATUAL
    if (cur_gx >= 0 && cur_gx < 28 && cur_gy >= 0 && cur_gy < 28) {
        vga_fill_rect_safe(
            lw,
            CANVAS_X + cur_gx * CELL_SIZE,
            CANVAS_Y + cur_gy * CELL_SIZE,
            CELL_SIZE, CELL_SIZE,
            C_RED
        );
        
        // Invalida o histórico da posição atual do cursor, pois na tela ela virou vermelha,
        // mas na matriz 'cells' ela continua sendo escala de cinza.
        c->old_cells[cur_gy][cur_gx] = 256; 

        last_cur_gx = cur_gx;
        last_cur_gy = cur_gy;
    }
}
*/

