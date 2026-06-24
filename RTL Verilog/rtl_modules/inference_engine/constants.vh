// OPCODES
`define OP_IMG      4'b0000
`define OP_PES_ADDR 4'b0001
`define OP_PES_DATA 4'b0010
`define OP_BIAS     4'b0011
`define OP_BETA     4'b0100
`define OP_START    4'b0101
`define OP_STATUS   4'b0110
`define OP_ACTV     4'b0111
`define OP_CYCLES   4'b1000

// Ativações
`define TANGENTE 2'b00
`define SIGMOID  2'b01
`define RELU     2'b10

// Display
`define SEG_OFF 7'h7F
`define SEG_I   7'h79
`define SEG_M   7'h2A
`define SEG_P   7'h0C
`define SEG_B   7'h03
`define SEG_G   7'h42
`define SEG_O   7'h40
`define SEG_A   7'h08
`define SEG_E   7'h06
`define SEG_R   7'h2F
`define SEG_Y   7'h11
`define SEG_U   7'h41
`define SEG_N   7'h2B
`define SEG_d   7'h21
`define SEG_T   7'h07
`define SEG_L   7'h47
`define SEG_S   7'h12

`define ZERO    7'h40
`define UM      7'h79
`define DOIS    7'h24
`define TRES    7'h30
`define QUATRO  7'h19
`define CINCO   7'h12
`define SEIS    7'h02
`define SETE    7'h78
`define OITO    7'h00
`define NOVE    7'h10