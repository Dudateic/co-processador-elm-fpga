#include <stdio.h>
#include <stdint.h>

void imprimirBitsInt(char* val, int n) {
    unsigned int mask = (unsigned int)n;

    printf("%s", val);
    int i;
    for (i = 31; i >= 0; i--) {
        printf("%d", (mask >> i) & 1);
    }

    printf("\n");
}
uint32_t make_instruction(
    uint8_t opcode,
    uint16_t addr,
    uint16_t data
) {
    return ((opcode & 0xF) << 28) |
           ((addr   & 0xFFF) << 16) |
           (data    & 0xFFFF);
}

int main () {
    uint8_t opcode = 0x6;
    uint16_t posicao = 2;
    uint16_t dado = 13;
    int R6 = ((opcode & 0xF) << 28) | 
                  ((posicao & 0xFFF) << 16) |
                  (dado     & 0xFFFF);

    imprimirBitsInt("R6: ", R6);
    imprimirBitsInt("R7: ", make_instruction(opcode, posicao, dado));
    return 0;
}