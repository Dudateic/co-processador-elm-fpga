#include "hps_0.h"

.section .data
	err_open:      .asciz "ERROR: could not open /dev/mem\n"
	err_mmap:      .asciz "ERROR: mmap() failed\n"
	err_munmap:    .asciz "ERROR: munmap() failed\n"
    err_open_file: .asciz "ERRO: Não foi possível abrir o arquivo."
	devmem:        .asciz "/dev/mem"

    len_err_open_file = devmem - err_open_file - 1

	@ Variáveis globais
	hps_fd:        .word 0
	hps_virtual:   .word 0


.section .text
	.global hps_open
	.global hps_close
    .global enviar_imagem


@ ============================================================================
@ void* hps_open(void)
@
@ Abre /dev/mem e mapeia o LW bridge
@
@ Retorna:
@   R0 = ponteiro virtual
@   R0 = 0 em erro
@ ============================================================================

hps_open:
    PUSH {R4, R5, R7, LR}

    @ ------------------------------------------------------------------------
    @ open("/dev/mem", O_RDWR | O_SYNC)
    @ ------------------------------------------------------------------------

    LDR R0, =devmem
    LDR R1, =(O_RDWR | O_SYNC)
    MOV R2, #0

    MOV R7, #SYS_OPEN
    SVC #0

    CMP R0, #0
    BLT .open_error

    @ salvar fd
    MOV R4, R0

    LDR R5, =hps_fd
    STR R4, [R5]

    @ ------------------------------------------------------------------------
    @ mmap2(
    @   NULL,
    @   LW_BRIDGE_SPAN,
    @   PROT_READ | PROT_WRITE,
    @   MAP_SHARED,
    @   fd,
    @   LW_BRIDGE_BASE >> 12
    @ )
    @ ------------------------------------------------------------------------

    MOV R0, #0
    LDR R1, =LW_BRIDGE_SPAN
    MOV R2, #(PROT_READ | PROT_WRITE)
    MOV R3, #MAP_SHARED
    @ 5º argumento = fd
    STR R4, [SP, #-4]! @ Salva na pilha
    @ 6º argumento = offset em páginas
    LDR R5, =(LW_BRIDGE_BASE >> 12)
    STR R5, [SP, #-4]! @ salva na pilha

    MOV R7, #SYS_MMAP2
    SVC #0

    ADD SP, SP, #8 @ remove r4 e r5 da pilha

    @ mmap falhou?
    CMP R0, #-1
    BEQ .mmap_error

    @ salvar ponteiro virtual
    LDR R5, =hps_virtual
    STR R0, [R5]

    B .hps_open_end

.open_error:
    MOV R0, #STDOUT
    LDR R1, =err_open
    MOV R2, #33

    MOV R7, #SYS_WRITE
    SVC #0

    MOV R0, #0
    B .hps_open_end


.mmap_error:
    MOV R0, #STDOUT
    LDR R1, =err_mmap
    MOV R2, #23

    MOV R7, #SYS_WRITE
    SVC #0

    @ fechar fd
    LDR R5, =hps_fd
    LDR R0, [R5]

    MOV R7, #SYS_CLOSE
    SVC #0

    MOV R0, #0


.hps_open_end:
    POP {R4, R5, R7, LR}
    BX LR


@ ============================================================================
@ int hps_close(void)
@
@ Desfaz mmap e fecha /dev/mem
@
@ Retorna:
@   R0 = 0 sucesso
@   R0 = -1 erro
@ ============================================================================

hps_close:
    PUSH {R4, R5, R7, LR}

    @ ------------------------------------------------------------------------
    @ munmap(hps_virtual, LW_BRIDGE_SPAN)
    @ ------------------------------------------------------------------------

    LDR R4, =hps_virtual
    LDR R0, [R4]

    LDR R1, =LW_BRIDGE_SPAN

    MOV R7, #SYS_MUNMAP
    SVC #0

    CMP R0, #0
    BNE .munmap_error

    @ ------------------------------------------------------------------------
    @ close(fd)
    @ ------------------------------------------------------------------------

    LDR R5, =hps_fd
    LDR R0, [R5]

    MOV R7, #SYS_CLOSE
    SVC #0

    @ limpar variáveis globais
    MOV R5, #0

    LDR R4, =hps_virtual
    STR R5, [R4]

    LDR R4, =hps_fd
    STR R5, [R4]

    MOV R0, #0
    B .close_end


.munmap_error:
    MOV R0, #STDOUT
    LDR R1, =err_munmap
    MOV R2, #24

    MOV R7, #SYS_WRITE
    SVC #0

    MOV R0, #-1


.close_end:
    POP {R4, R5, R7, LR}
    BX LR

@ |========================================>
@ Abrir arquivo com base em um caminho
@   R0: Caminho do arquivo .raw ou .bin
@
@   RETURN: FD do arquivo
@ |========================================/
abrir_arquivo:
    PUSH {R7, LR}
    
    MOV R1, #O_RDONLY
    MOV R2, #READ_MODE

    MOV R7, #SYS_OPEN
    SVC #0

    CMP R0, #0
    BLT .file_open_error

    POP {R7, PC}

.file_open_error:
    MOV R0, #STDOUT
    LDR R1, =err_open_file
    MOV R2, #len_err_open_file

    MOV R7, #SYS_WRITE
    SVC #0

    MOV R0, #0

    POP {R7, PC}

@ |========================================>
@ Enviar instruções basicas para a FPGA
@    r0 = lw_virtual
@    r1 = opcode
@    r2 = addr
@    r3 = data
@ |========================================/
enviar_instrucao_base:
    PUSH {R4, R5, LR}

    AND R1, R1, #0xF

    LDR R4, =0xFFF
    AND R2, R2, R4

    LDR R4, =0xFFFF
    AND R3, R3, R4

    LSL R4, R1, #28
    LSL R5, R2, #16
    ORR R4, R4, R5
    ORR R4, R4, R3

    STR R4, [R0, #INST_BASE]      @ R0 = lw_virtual (volta a ser usado)

    MOV R1, #0
    STR R1, [R0, #ENABLE_BASE]
    MOV R1, #1
    STR R1, [R0, #ENABLE_BASE]

.loop_enable:
    LDR R1, [R0, #DONE_BASE]
    CMP R1, #0
    BEQ .loop_enable

    MOV R1, #0
    STR R1, [R0, #ENABLE_BASE]

    POP {R4, R5, LR}
    BX LR

@ |========================================>
@ Envia uma imagem para a ser escrita na memória
@ do co-processador na FPGA
@   R0 = lw_virtual 
@   R1 = caminho
@       string contendo o caminho para o arquivo contendo
@       os dados a serem passados.
@       O arquivo deve estar em .raw ou .bin (sem headers)
@       com pixels de 8 bits para o procedimento
@       funcionar corretamente.
@
@   RETURN: 0 se o procedimento funcionou ou -1 se
@           houve algum problema.
@ |========================================/
enviar_imagem:
    PUSH {R4-R8, LR}
    SUB SP, SP, #4      @ Aloca 4 bytes na stack

    MOV R4, R0          @ R4 = LW_Virtual
    MOV R5, R1          @ R5 = Caminho

    MOV R0, R5
    BL abrir_arquivo

    MOV R6, R0          @ R6 = FD

    CMP R0, #0
    BEQ .return_error_IMG

    MOV R7, #SYS_READ
    MOV R8, #-1         @ Contador de endereço

.loop_img:
    MOV R0, R6
    MOV R1, SP          @ O buffer é o topo da stack
    MOV R2, #1          @ Lê um byte (cada píxel tem 8bits)
    SVC #0

    CMP R0, #1
    BNE .fim

    MOV R0, R4          @ Parâmetro 1: LW_virtual
    MOV R1, #OP_IMG     @ Parâmetro 2: OP_Code
    ADD R8, R8, #1      @ 
    MOV R2, R8          @ Parâmetro 3: Endereço
    LDRB R3, [SP]       @ Parâmetro 4: Dado
    BL enviar_instrucao_base

    CMP R8, #783
    BLT .loop_img

.fim:
    MOV R0, R6
    MOV R7, #SYS_CLOSE
    SVC #0

    ADD SP, SP, #4
    MOV R0, #0
    POP {R4-R8, PC}

.return_error_IMG:
    ADD SP, SP, #4
    MOV R0, #-1
    POP {R4-R8, PC}
