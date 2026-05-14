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
	.global ledr_write
	.global sw_read


@ ============================================================================
@ CONSTANTES
@ ============================================================================

.equ LW_BRIDGE_BASE,    0xFF200000
.equ LW_BRIDGE_SPAN,    0x00005000

.equ INST_BASE,         0x00000010
.equ LEDR_BASE,         0x00000000
.equ SW_BASE,           0x00000040
@ Adicionar offsets do coprocessador

@ Syscalls ARMv7 Linux
.equ SYS_OPEN,         5
.equ SYS_CLOSE,        6
.equ SYS_WRITE,        4
.equ SYS_MMAP2,        192
.equ SYS_MUNMAP,       91

@ open flags
.equ O_RDWR,           2
.equ O_SYNC,           0x101000

.equ O_RDONLY          0x00
.equ READ_MODE         0x00

@ mmap flags
.equ PROT_READ,        1
.equ PROT_WRITE,       2
.equ MAP_SHARED,       1

.equ STDOUT,           1


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

    B .open_end

.open_error:
    MOV R0, #STDOUT
    LDR R1, =err_open
    MOV R2, #33

    MOV R7, #SYS_WRITE
    SVC #0

    MOV R0, #0
    B .open_end


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

/**
    Envia a imagem completamente para a fpga.
    R0: LW_Virtual
    R1: Caminho do arquivo .bin
    R2: Tamanho do arquivo
 */

.abrir_arquivo:
    PUSH {R7, LR}
    
    MOV R1, #O_RDONLY
    MOV R2, #READ_MODE

    MOV R7, #SYS_OPEN
    SVC #0

    CMP R0, #0
    BLT .file_open_error
    B abrir_arquivo_fim

.file_open_error:
    MOV R0, #STDOUT
    LDR R1, =err_open_file
    MOV R2, #len_err_open_file

    MOV R7, #SYS_WRITE
    SVC #0

    MOV R0, #0
.abrir_arquivo_fim:
    POP {R7, PC}


enviar_instrucao_base:



enviar_imagem:
    PUSH {R4-R7, LR}
    SUB SP, SP, #4      @ Aloca 4 bytes na stack

    MOV R4, R0
    MOV R5, R1

    MOV R0, R5
    BL abrir_arquivo

    MOV R6, R0

    CMP R0, #0
    BEQ .return_error_IMG
.loop_img:
    MOV R0, R6
    MOV R1, SP @ O buffer é o topo da stack
    MOV R2, #2
    MOV R7, #3
    SVC #0

    CMP R0, #1
    BLT .fim

    LDRSH R1, [SP]

    MOV R0, R4
    BL .instrucao_imagem


.return_error_IMG:
    MOV R0, #-1
    POP {R4-R7, PC}

.fim:
    MOV R0, R6
    MOV R7, #SYS_CLOSE
    SVC #0

    ADD SP, SP, #4
    POP {R4-R7, PC}
