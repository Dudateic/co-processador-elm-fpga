#include "hps_0.h"

.section .bss
.align 2
    image_buffer:   .skip 784         @ abre 784 bytes de espaço
    bias_buffer:    .skip 256         @ 128 bytes * 2
    beta_buffer:    .skip 2560        @ 1280 bytes * 2
    pesos_buffer:   .skip 200704      @ 100352 bytes * 2

    hps_fd:         .space 4          @ 4 bytes para o FD

.section .data
    err_open_file: .asciz "ERRO: Não foi possível abrir o arquivo.\n"
    len_err_open_file = . - err_open_file

    devmem:        .asciz "/dev/mem"
    image_filename: .asciz image_file
    bias_filename:  .asciz bias_file
    betas_filename: .asciz beta_file
    pesos_filename: .asciz pesos_file

.section .text
    .global hps_open        @ void* hps_open(void)
    .global hps_close       @ int hps_close(void* lw_virtual)
    .global reset_cop       @ void reset_cop(void* lw_virtual)
    .global get_result      @ int32_t get_result(void* lw_virtual) -> Result
    .global get_status      @ int32_t get_status(void* lw_virtual) -> result
    .global start_inf       @ int32_t start_inf(void* lw_virtual) -> Result
    .global enviar_imagem   @ int enviar_imagem(void* lw_virtual)
    .global enviar_pesos    @ int enviar_pesos(void* lw_virtual)
    .global enviar_bias     @ int enviar_bias(void* lw_virtual)
    .global enviar_beta     @ int enviar_beta(void* lw_virtual)
    .global set_activation  @ void set_activation(void* lw_virtual, int tipo_ativacao)
    .global get_cycles      @ uint32_t get_cycles(void* lw_virtual)



@ ============================================================================
@ void* hps_open(void)
@ Inicializa o HPS e retorna o ponteiro LW_virtual
@ ============================================================================
.type hps_open, %function
hps_open:
    PUSH {R4-R5, R7, LR}

    @ open("/dev/mem", O_RDWR | O_SYNC)
    LDR R0, =devmem
    LDR R1, =0x101002  @ O_RDWR | O_SYNC (Ignora a cache L1/L2 e escreve direto na FPGA)
    MOV R2, #0
    MOV R7, #SYS_OPEN
    SVC #0

    CMP R0, #0
    BLT .err_open_devmem

    MOV R4, R0       @ Salva FD em R4     

    @ mmap2(NULL, span, PROT_READ|PROT_WRITE, MAP_SHARED, fd, base >> 12)
    MOV R0, #0
    LDR R1, =LW_BRIDGE_SPAN
    MOV R2, #3              
    MOV R3, #MAP_SHARED      
    LDR R5, =LW_BRIDGE_BASE      

    MOV R7, #SYS_MMAP2
    SVC #0

    CMN R0, #1
    BEQ .mmap_falhou

    MOV R5, R0
    B .close_fd_exit

.mmap_falhou:
    MOV R5, #0

.close_fd_exit:
    MOV R0, R4
    BL fechar_arquivo

    MOV R0, R5
    POP {R4-R5, R7, PC}

.err_open_devmem:
    MOV R0, #-1
    POP {R4-R5, R7, PC}

@ ============================================================================
@ int hps_close(void* lw_virtual)
@ ============================================================================
.type hps_close, %function
hps_close:
    PUSH {R7, LR} 

    CMP R0, #0
    BEQ .close_done       

    @ munmap(lw_virtual, span)
    LDR R1, =LW_BRIDGE_SPAN
    MOV R7, #SYS_MUNMAP
    SVC #0
.close_done:
    POP {R7, PC}

@ ============================================================================
@ INT32 get_result(void* lw_virtual) -> Result
@ ============================================================================
.type get_result, %function
get_result:
    LDR R0, [R0, #OUT_BASE]
    BX LR

@ ============================================================================
@ void reset_cop(void* base)
@ ============================================================================
.type reset_cop, %function
reset_cop:
    PUSH {R4, R5, LR}

    MOV R4, #1
    STR R4, [R0, #RESET_BASE]   @ 1. Levanta o sinal de Reset

    @ Atraso de Software (~1000 iterações garantem dezenas de ciclos na FPGA)
    LDR R5, =1000
.delay_reset_1:
    SUBS R5, R5, #1
    BNE .delay_reset_1

    MOV R4, #0
    STR R4, [R0, #RESET_BASE]   @ 2. Baixa o sinal de Reset

    @ Atraso de Software secundário (Garante estabilização antes da próxima instrução)
    LDR R5, =1000
.delay_reset_2:
    SUBS R5, R5, #1
    BNE .delay_reset_2

    POP {R4, R5, PC}


@ ============================================================================
@ int32_t get_status(void* lw_virtual) -> result
@ ============================================================================
.type get_status, %function
get_status:
    PUSH {R4, R5, LR}
    MOV R5, R0

    MOV R4, #OP_STATUS
    LSL R4, R4, #28
    STR R4, [R0, #INST_BASE]

    MOV R0, R5
    BL loop_enable

    LDR R0, [R0, #OUT_BASE]
    POP {R4, R5, PC}

@ ============================================================================
@ INT32 start_inf(void* lw_virtual) -> Result
@ ============================================================================
.type start_inf, %function
start_inf:
    PUSH {R4, R5, LR}
    MOV R5, R0

    MOV R4, #OP_START
    LSL R4, R4, #28

    STR R4, [R0, #INST_BASE]

    MOV R0, R5
    BL loop_enable

    LDR R0, [R0, #OUT_BASE]

    POP {R4, R5, PC}

@ ============================================================================
@ void set_activation(void* lw_virtual, int tipo_ativacao)
@ R0: lw_virtual (Endereço base da ponte leve)
@ R1: tipo_ativacao (00 = Tanh, 01 = Sigmoid, 10 = ReLU)
@ ============================================================================
.type set_activation, %function
set_activation:
    PUSH {R6, LR}

    MOV R6, #OP_ACTV
    LSL R6, R6, #28

    AND R1, R1, #3

    ORR R6, R6, R1

    STR R6, [R0, #INST_BASE]

    BL loop_enable

    POP {R6, PC}

@ ============================================================================
@ uint32_t get_cycles(void* lw_virtual)
@ R0: lw_virtual (Endereço base da ponte leve)
@ Retorna: Valor de 32 bits contendo a contagem exata de ciclos da inferência
@ ============================================================================
.type get_cycles, %function
get_cycles:
    PUSH {R5-R6, LR}
    MOV R5, R0

    MOV R6, #OP_CYCLES
    LSL R6, R6, #28

    STR R6, [R0, #INST_BASE]
    MOV R0, R5
    BL loop_enable

    LDR R0, [R0, #OUT_BASE]

    POP {R5-R6, PC}

@ ============================================================================
@ int enviar_imagem(void* lw_virtual)
@ Retorna: 0 se sucesso, -1 se erro de arquivo
@ ============================================================================
.type enviar_imagem, %function
enviar_imagem:
    PUSH {R4-R10, LR}

    MOV R8, R0              @ salva base FPGA

    LDR R0, =image_filename @ Abre img.bin
    BL abrir_arquivo
    MOV R6, R0              @ FD

    CMP R6, #0
    BLT .err_img_file

    @ Lê 784 bytes para image_buffer

    LDR R1, =image_buffer
    MOV R2, #image_size

    MOV R7, #SYS_READ
    MOV R0, R6
    SVC #0

    LDR R4, =image_buffer
    MOV R7, #0              @ addr = 0

.store_image_loop:
    CMP R7, #N_image
    BGE .fim_img

    MOV R0, R8              @ Parâmetro 1: base hps_virtua
    MOV R1, #OP_IMG         @ Parâmetro 2: opcode
    MOV R2, R7              @ Parâmetro 3: endereço
    LDRB R3, [R4], #1       @ Parâmetro 4: valor

    BL send_inst

    ADD R7, R7, #1
    B .store_image_loop

.fim_img:
    MOV R0, R6
    BL fechar_arquivo
    MOV R0, #0
    POP {R4-R10, PC}
    
.err_img_file:
    MOV R0, #-1
    POP {R4-R10, PC}

@ ============================================================================
@ int enviar_pesos(void* lw_virtual)
@ Retorna: 0 se sucesso, -1 se erro de arquivo
@ ============================================================================
.type enviar_pesos, %function
enviar_pesos:
    PUSH {R4-R10, LR}

    MOV R8, R0

    LDR R0, =pesos_filename
    BL abrir_arquivo
    MOV R6, R0

    CMP R6, #0
    BLT .err_pesos_file

    LDR R1, =pesos_buffer
    LDR R2, =pesos_size

    MOV R7, #SYS_READ
    MOV R0, R6
    SVC #0

    LDR R4, =pesos_buffer
    LDR R5, =N_pesos
    MOV R7, #0              @ CONTADOR
.store_pesos_loop:
    CMP R7, R5
    BGE .fim_pesos

    @== Enviar endereço do Peso
    MOV R0, R8              @ base HPS
    MOV R1, R7              @ endereço
    BL send_weight_addr

    @== Enviar dado do Peso
    MOV R0, R8                  @ Parâmetro 1: base hps_virtual
    MOV R1, #OP_PES_DATA        @ Parâmetro 2: opcode
    MOV R2, #0                  @ Parâmetro 3: endereço
    LDRH R3, [R4], #2           @ Parâmetro 4: valor

    BL send_inst

    ADD R7, R7, #1
    B .store_pesos_loop

.fim_pesos:
    MOV R0, R6
    BL fechar_arquivo
    MOV R0, #0
    POP {R4-R10, PC}

.err_pesos_file:
    MOV R0, #-1
    POP {R4-R10, PC}

@ ============================================================================
@ int enviar_bias(void* lw_virtual)
@ Retorna: 0 se sucesso, -1 se erro de arquivo
@ ============================================================================
.type enviar_bias, %function
enviar_bias:
    PUSH {R4-R10, LR}

    MOV R8, R0
    
    LDR R0, =bias_filename
    BL abrir_arquivo
    MOV R6, R0

    CMP R6, #0
    BLT .err_bias_file

    LDR R1, =bias_buffer    
    LDR R2, =bias_size

    MOV R7, #SYS_READ
    MOV R0, R6
    SVC #0

    LDR R4, =N_bias
    LDR R5, =bias_buffer
    MOV R7, #0

.store_bias_loop:
    CMP R7, R4
    BGE .fim_bias

    MOV R0, R8              @ Parâmetro 1: base hps_virtual
    MOV R1, #OP_BIAS        @ Parâmetro 2: opcode
    MOV R2, R7              @ Parâmetro 3: endereço
    LDRH R3, [R5], #2       @ Parâmetro 4: valor

    BL send_inst

    ADD R7, R7, #1
    B .store_bias_loop

.fim_bias:
    MOV R0, R6
    BL fechar_arquivo
    MOV R0, #0
    POP {R4-R10, PC}

.err_bias_file:
    MOV R0, #-1
    POP {R4-R10, PC}

@ ============================================================================
@ int enviar_beta(void* lw_virtual)
@ Retorna: 0 se sucesso, -1 se erro de arquivo
@ ============================================================================
.type enviar_beta, %function
enviar_beta:
    PUSH {R4-R10, LR}

    MOV R8, R0
    
    LDR R0, =betas_filename
    BL abrir_arquivo
    MOV R6, R0

    CMP R6, #0
    BLT .err_beta_file

    LDR R1, =beta_buffer    
    LDR R2, =beta_size

    MOV R7, #SYS_READ
    MOV R0, R6
    SVC #0

    LDR R4, =N_beta
    LDR R5, =beta_buffer
    MOV R7, #0

.store_beta_loop:
    CMP R7, R4
    BGE .fim_beta

    MOV R0, R8              @ Parâmetro 1: base hps_virtual
    MOV R1, #OP_BETA        @ Parâmetro 2: opcode
    MOV R2, R7              @ Parâmetro 3: endereço
    LDRH R3, [R5], #2       @ Parâmetro 4: valor

    BL send_inst

    ADD R7, R7, #1
    B .store_beta_loop

.fim_beta:
    MOV R0, R6
    BL fechar_arquivo
    MOV R0, #0
    POP {R4-R10, PC}

.err_beta_file:
    MOV R0, #-1
    POP {R4-R10, PC}

# /=================================================================/

@ ============================================================================
@ int abrir_arquivo(char* caminho)
@
@ R0: Caminho do arquivo
@ Retorna: File Descriptor para o arquivo
@ ============================================================================
abrir_arquivo:
    PUSH {R7, LR}
    MOV R7, #SYS_OPEN
    MOV R1, #READ_ONLY
    SVC #0

    CMP R0, #0
    BLT .err_file
    
    POP {R7, PC}

.err_file:
    MOV R0, #-1
    POP {R7, PC}

@ ============================================================================
@ int fechar_arquivo(void* FD)
@
@ R0: File Descriptor para o arquivo
@ ============================================================================
fechar_arquivo:
    PUSH {R7, LR}

    CMP R0, #0
    BLT .err_close

    MOV R7, #SYS_CLOSE
    SVC #0
    POP {R7, PC}

.err_close:
    MOV R0, #-1
    POP {R7, PC}


@ ============================================================================
@ void send_inst(void* base, int opcode, int addr, int data)
@ ============================================================================
send_inst:
    PUSH {R4-R5, LR}

    AND R1, R1, #0xF        @ Opcode & 0xF
    LSL R5, R1, #0x1C       @ R5 = opcode << 28

    LDR R4, =0xFFF          
    AND R2, R2, R4
    LSL R2, R2, #0x10       @ R2 = addr << 16

    ORR R5, R5, R2          @ R5 = R5 | R2

    LDR R4, =0xFFFF
    AND R3, R3, R4

    ORR R5, R5, R3          @ R5 = R5 | data

    STR R5, [R0, #INST_BASE]   @ Guarda instrução no PIO

    @ Inicia envio
    BL loop_enable

    POP {R4, R5, PC}


@ ============================================================================
@ void send_weight_addr(void* base, int addr)
@ ============================================================================
send_weight_addr:
    PUSH {R4-R6, LR}

    MOV R2, #OP_PES_ADDR
    LSL R2, R2, #28         @ R2 = opcode << 28

    LDR R4, =0x1FFFF
    AND R1, R1, R4          @ limpa os bits [16:0]

    ORR R2, R2, R1          @ R2 = R2 | dado

    STR R2, [R0, #INST_BASE]

    MOV R4, #1
    STR R4, [R0, #ENABLE_BASE]
    
    MOV R6, #100
.delay_addr_1:
    SUBS R6, R6, #1
    BNE .delay_addr_1

    MOV R4, #0
    STR R4, [R0, #ENABLE_BASE]
        
    MOV R6, #100
.delay_addr_2:
    SUBS R6, R6, #1
    BNE .delay_addr_2

    POP {R4-R6, PC}

@ ============================================================================
@ void loop_enable(void* lw_virtual)
@ Controla o barramento de Handshake (Subida, Espera, Descida e Limpeza de Estado)
@ ============================================================================
loop_enable:
    PUSH {R4-R5, LR}

    MOV R4, #1
    STR R4, [R0, #ENABLE_BASE]

.loop_inf_sobe:
    LDR R5, [R0, #DONE_BASE]
    CMP R5, #0
    BEQ .loop_inf_sobe       @ 1. Espera FPGA concluir (DONE == 1)

    MOV R4, #0
    STR R4, [R0, #ENABLE_BASE]

.loop_inf_desce:
    LDR R5, [R0, #DONE_BASE]
    CMP R5, #0
    BNE .loop_inf_desce      @ 2. CRÍTICO: Espera FPGA limpar o estado (DONE == 0)

    POP {R4-R5, PC}