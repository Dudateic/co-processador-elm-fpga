#ifndef VGA_PIO_H
#define VGA_PIO_H


#include <stdint.h>
#include "hps_0.h"

#define VGA_WIDTH   320
#define VGA_HEIGHT  240

int vga_put_pixel_safe(volatile void *lw, 
                        uint16_t x, 
                        uint16_t y, 
                        uint8_t r, 
                        uint8_t g, 
                        uint8_t b);
/*
int vga_fill_rect_safe(volatile void *lw,
                       uint16_t x0, uint8_t y0,
                       uint16_t w, uint8_t h,
                       uint8_t r, uint8_t g, uint8_t b);
*/
void vga_show_buffer(void *lw);

int vga_fill_safe(volatile void *lw,
                             uint8_t r,
                             uint8_t g, 
                             uint8_t b);


int vga_put_pixel(volatile void *lw,
                  uint16_t x, uint8_t y,
                  uint8_t r, uint8_t g, uint8_t b);

int vga_fill(volatile void *lw,
             uint8_t r, uint8_t g, uint8_t b);

int vga_fill_rect(volatile void *lw,
                  uint16_t x0, uint16_t y0,
                  uint16_t w, uint16_t h,
                  uint8_t r, uint8_t g, uint8_t b);

int vga_draw_border(volatile void *lw,
                    uint16_t x0, uint16_t y0,
                    uint16_t w, uint16_t h,
                    uint8_t r, uint8_t g, uint8_t b);
#endif /* VGA_PIO_H */