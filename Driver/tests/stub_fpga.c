#include <stdio.h>
#include <stdint.h>

void imprimir_instrucao(uint32_t opcode, uint32_t addr,
                        uint32_t data,   uint32_t instrucao) {
    printf("[STUB] opcode=0x%X  addr=%4u (0x%03X)  data=%3u (0x%02X)"
           "  |  instrução=0x%08X\n",
           opcode, addr, addr, data, data, instrucao);
}