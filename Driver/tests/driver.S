.syntax unified
.arch armv7-a
.arm  

.section .data
    err_open_file: .asciz "ERRO: Não foi possível abrir o arquivo da imagem.\n"
    len_err_open_file = . - err_open_file

    devmem:        .asciz "/dev/mem"

.section .text
    .global hps_open
    .global hps_close
    .global enviar_imagem
    .global abrir_arquivo

@ Configurações da Ponte LW (Lightweight HPS-to-FPGA Bridge)
.equ LW_BRIDGE_BASE,  0xff200     @ Endereço físico 0xFF200000 mapeado em páginas (>> 12)
.equ LW_BRIDGE_SPAN,  0x00005000  @ Tamanho do bloco de memória a mapear

/**
 * Offsets dos Registradores na FPGA
 */
.equ INST_BASE,       0x20
.equ OUT_BASE,        0x30
.equ ENABLE_BASE,     0x40
.equ BUSY_BASE,       0x50
.equ RESET_BASE,      0x60
.equ DONE_BASE,       0x70

/**
 * Opcodes do Co-processador
 */
.equ OP_IMG,          0x00

/**
 * System Calls do Linux ARMv7
 */
.equ SYS_READ,        3
.equ SYS_WRITE,       4
.equ SYS_OPEN,        5
.equ SYS_CLOSE,       6
.equ SYS_MUNMAP,      91
.equ SYS_MMAP2,       192

@ Flags
.equ MAP_SHARED,      1
.equ STDOUT,          1

@ ============================================================================
@ void* hps_open(void)
@ ============================================================================
.type hps_open, %function
hps_open:
    PUSH {R4-R5, LR}

    @ open("/dev/mem", O_RDWR | O_SYNC)
    LDR R0, =devmem
    LDR R1, =0x101002       
    MOV R2, #0
    MOV R7, #SYS_OPEN
    SVC #0

    CMP R0, #0
    BLT .open_error          

    MOV R4, R0              

    @ mmap2(NULL, span, PROT_READ|PROT_WRITE, MAP_SHARED, fd, base >> 12)
    MOV R0, #0
    LDR R1, =LW_BRIDGE_SPAN
    MOV R2, #3              
    MOV R3, #MAP_SHARED

    SUB SP, SP, #8          
    STR R4, [SP, #4]        
    LDR R5, =LW_BRIDGE_BASE
    STR R5, [SP, #0]        

    MOV R7, #SYS_MMAP2
    SVC #0

    ADD SP, SP, #8          

    CMP R0, #-1
    BEQ .mmap_error         

    B .open_end

.open_error:
    MOV R0, #0
    B .open_end

.mmap_error:
    MOV R0, R4
    MOV R7, #SYS_CLOSE
    SVC #0
    MOV R0, #0

.open_end:
    POP {R4-R5, LR}
    BX LR

@ ============================================================================
@ int hps_close(void* lw_virtual)
@ ============================================================================
.type hps_close, %function
hps_close:
    PUSH {R4, LR}

    CMP R0, #0
    BEQ .close_fail         

    MOV R4, R0          

    @ munmap(lw_virtual, span)
    LDR R1, =LW_BRIDGE_SPAN
    MOV R7, #SYS_MUNMAP
    SVC #0

    CMP R0, #0
    BNE .close_fail

    MOV R0, #0
    B .close_end

.close_fail:
    MOV R0, #-1

.close_end:
    POP {R4, LR}
    BX LR

@ ============================================================================
@ int abrir_arquivo(char* caminho)
@
@ MOCK DE TESTE: Ignora o arquivo real e retorna sempre a constante 4.
@ ============================================================================
.type abrir_arquivo, %function
abrir_arquivo:
    PUSH {R7, LR}
    MOV R0, #4              @ Força o File Descriptor a ser sempre 4 para teste
    POP {R7, PC}

@ ============================================================================
@ void enviar_instrucao_base(void* lw_virtual, int op, int addr, int data)
@
@ Monta o pacote, PRINTA o valor em Hexadecimal no terminal e faz o handshake.
@ ============================================================================
enviar_instrucao_base:
    PUSH {R4-R7, LR}        

    @ 1. Sanitização dos dados de entrada
    LDR R4, =0xFFF
    AND R2, R2, R4          @ Endereço truncado para 12 bits

    LDR R4, =0xFFFF
    AND R3, R3, R4          @ Dado truncado para 16 bits

    AND R1, R1, #0xF        @ Opcode truncado para 4 bits

    @ 2. Montagem do pacote de 32 bits: [OP (4b) | ADDR (12b) | DATA (16b)]
    LSL R4, R1, #28
    LSL R2, R2, #16         
    ORR R4, R4, R2
    ORR R4, R4, R3          @ R4 = Instrução completa de 32 bits

    @ ========================================================================
    @ INTERCEPTAÇÃO: Rotina para printar R4 no terminal em formato "0xXXXXXXXX\n"
    @ ========================================================================
    MOV R5, R0              @ Salva lw_virtual em R5
    MOV R6, R4              @ Salva a instrução montada em R6
    
    @ Aloca espaço na stack para a string "0xXXXXXXXX\n" (11 bytes + alinhamento)
    SUB SP, SP, #12         
    MOV R0, #0x30           @ Caractere '0'
    STRB R0, [SP, #0]
    MOV R0, #0x78           @ Caractere 'x'
    STRB R0, [SP, #1]
    MOV R0, #0x0A           @ Caractere '\n' (Quebra de linha no final)
    STRB R0, [SP, #10]

    @ Converte os 32 bits para caracteres ASCII de trás para frente
    MOV R1, #7              
.loop_ascii:
    AND R2, R4, #0xF        @ Isola o dígito hexadecimal atual (4 bits)
    CMP R2, #10
    ADDLT R2, R2, #48       @ Converte para '0'-'9'
    ADDGE R2, R2, #55       @ Converte para 'A'-'F'
    
    ADD R3, R1, #2          @ Pula o prefixo "0x"
    STRB R2, [SP, R3]       @ Guarda o caractere na string
    
    LSR R4, R4, #4          @ Avança para o próximo dígito hexadecimal
    SUBS R1, R1, #1
    BGE .loop_ascii

    @ Executa o print via System Call
    MOV R7, #SYS_WRITE
    MOV R0, #STDOUT
    MOV R1, SP              
    MOV R2, #11             
    SVC #0

    @ Restaura o estado anterior ao print
    ADD SP, SP, #12         
    MOV R0, R5              
    MOV R4, R6              
    @ ========================================================================

    @ 3. Escreve a instrução no registrador físico da FPGA
    STR R4, [R0, #INST_BASE]
    DSB
    ISB

    @ 4. Pulsa o ENABLE (0 -> 1)
    MOV R1, #0
    STR R1, [R0, #ENABLE_BASE]
    MOV R1, #1
    STR R1, [R0, #ENABLE_BASE]
    DSB

.loop_enable:
    @ Aguarda a resposta (Handshake) do sinal DONE vindo da FPGA
    LDR R1, [R0, #DONE_BASE]
    CMP R1, #0
    BEQ .loop_enable        

    @ 5. Finaliza desativando o ENABLE (1 -> 0)
    MOV R1, #0
    STR R1, [R0, #ENABLE_BASE]
    DSB                     

    POP {R4-R7, LR}
    BX LR

@ ============================================================================
@ int enviar_imagem(void* lw_virtual, char* caminho)
@
@ VERSÃO DE TESTE ESTÁTICO: Guarda um número (ex: 255) estritamente no índice 0
@ ============================================================================
.type enviar_imagem, %function
enviar_imagem:
    PUSH {R4-R9, LR}
    SUB SP, SP, #8          @ Garante o alinhamento de stack de 8-bytes

    MOV R4, R0              @ R4 = lw_virtual

    @ --- TESTE DE GRAVAÇÃO DIRETA NO ÍNDICE 0 ---
    MOV R0, R4              @ Parâmetro 1: lw_virtual
    MOV R1, #OP_IMG         @ Parâmetro 2: Opcode da Imagem (0x00)
    MOV R2, #0              @ Parâmetro 3: ÍNDICE / ENDEREÇO = 0
    MOV R3, #255            @ Parâmetro 4: DADO = 255 (Ajuste o número aqui se quiser)
    
    BL enviar_instrucao_base

    @ Finaliza retornando sucesso (0) sem varrer arquivo
    ADD SP, SP, #8
    MOV R0, #0
    POP {R4-R9, LR}
    BX LR

.section .note.GNU-stack, "", %progbits