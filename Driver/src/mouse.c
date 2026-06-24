#include "mouse.h"
#include "vga.h"
#include "api.h"
#include "print.h"
#include "buffers.h"

#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdbool.h>

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
#include "stb_image_write.h"
#pragma GCC diagnostic pop

#define MOUSE_DEV   "/dev/input/mouse0"


#define LARGURA_IMG 28
#define ALTURA_IMG  28

int salvar_buffer_png(const char *nome_arquivo, uint8_t *buffer_pixels) {

    int canais = 1;
    int stride = LARGURA_IMG * canais;
    
    int resultado = stbi_write_png(nome_arquivo, LARGURA_IMG, ALTURA_IMG, canais, buffer_pixels, stride);
    
    if (resultado == 0) {
        fprintf(stderr, "Erro: stb_image_write falhou ao gerar o arquivo PNG.\n");
        return -1;
    }

    printf("Sucesso! Arquivo PNG '%s' gerado com sucesso.\n", nome_arquivo);
    return 0;
}


void modo_desenho(void *lw_void) {
    volatile void *lw = (volatile void *)lw_void;

    int mouse_fd = open(MOUSE_DEV, O_RDONLY | O_NONBLOCK);
    if (mouse_fd < 0) {
        printf("Erro ao abrir o mouse em %s\n", MOUSE_DEV);
        return;
    }

    Canvas canvas;
    canvas_clear(&canvas);
    ui_clear(lw);

    int cur_gx = 13, cur_gy = 13;
    int cur_px = VGA_WIDTH / 2;
    int cur_py = VGA_HEIGHT / 2;

    canvas_render(lw, &canvas, cur_gx, cur_gy);

    uint8_t pkt[3];
    int idx = 0;
    bool need_render = false;

    while (1) {
        uint8_t b;
        if (read(mouse_fd, &b, 1) == 1) {
            if (idx == 0 && !(b & 0x08)) continue;
            pkt[idx++] = b;

            if (idx == 3) {
                idx = 0;
                need_render = true;
                uint8_t buttons = pkt[0];
                int8_t dx = pkt[1];
                int8_t dy = pkt[2];

                cur_px += dx;
                cur_py -= dy;

                if (cur_px < 0) cur_px = 0;
                if (cur_py < 0) cur_py = 0;

                int gx = (cur_px - CANVAS_X) / CELL_SIZE;
                int gy = (cur_py - CANVAS_Y) / CELL_SIZE;

                bool inside = (gx >= 0 && gx < 28 && gy >= 0 && gy < 28);

                if (inside) {
                    cur_gx = gx;
                    cur_gy = gy;
                }

                if ((buttons & 0x01) && (buttons & 0x02)) {
                    print_header("Saindo do modo desenho...");
                    break; 
                }

                // Clique Esquerdo: Desenhar
                if ((buttons & 0x01) && inside) {
                    canvas_paint(&canvas, gx, gy);
                    need_render = true;
                }

                // Clique Direito: Apagar célula
                if ((buttons & 0x02) && inside) {
                    canvas_clear(&canvas);
                    need_render = true;
                }

                // Clique do Meio: Exportar, Salvar e Inferir
                if (buttons & 0x04) {
                    canvas_export(&canvas);

                if (salvar_buffer_png("./saida.png", buffer_image) == 0) {
                        print_header("PNG salvo com sucesso na raiz do projeto!\n");
                    }

                    if (enviar_imagem(lw_void, buffer_image) == 0) {
                        int32_t st = start_inf(lw_void);
                        int32_t cy = get_cycles(lw_void);

                        if (st >= 0) {
                            printf("PREDICAO: %d\n", st & 0xF);
                            printf("CICLOS  : %d\n", cy);
                        } else {
                            printf("ERRO inferencia: %d\n", st);
                        }
                    }
                    need_render = true;
                }
            }
        }

        if (need_render) {
            canvas_render(lw, &canvas, cur_gx, cur_gy);
            need_render = false;
            canvas_render(lw, &canvas, cur_gx, cur_gy);
        }
    }

    close(mouse_fd);
}