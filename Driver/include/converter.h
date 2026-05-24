#ifndef CONVERTER_H
#define CONVERTER_H

#include <stdint.h>

void load_mif_image(const char *filename, uint8_t *buffer);
int load_mif_u16(const char *filename, uint16_t *buffer, uint32_t max_count);
int png_para_raw(const char* png_path, const char* raw_path);
int save_bin_u16(const char *path, const uint16_t *buffer, uint32_t count);

#endif