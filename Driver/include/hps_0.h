#ifndef HPS_0_H
#define HPS_0_H

#define PIO_LED_BASE 0x0
#define PIO_LED_SPAN 16
#define PIO_LED_END 0xf
#define PIO_LED_BIT_CLEARING_EDGE_REGISTER 0
#define PIO_LED_BIT_MODIFYING_OUTPUT_REGISTER 0
#define PIO_LED_CAPTURE 0
#define PIO_LED_DATA_WIDTH 10
#define PIO_LED_DO_TEST_BENCH_WIRING 0
#define PIO_LED_DRIVEN_SIM_VALUE 0
#define PIO_LED_EDGE_TYPE NONE
#define PIO_LED_FREQ 50000000
#define PIO_LED_HAS_IN 0
#define PIO_LED_HAS_OUT 1
#define PIO_LED_HAS_TRI 0
#define PIO_LED_IRQ_TYPE NONE
#define PIO_LED_RESET_VALUE 1023

#define LW_BRIDGE_BASE_TOTAL  0xFF200000
#define LW_BRIDGE_BASE  0xFF200
#define LW_BRIDGE_SPAN  0x01000

#define INST_BASE       0x20
#define OUT_BASE        0x30
#define ENABLE_BASE     0x40
#define BUSY_BASE       0x50
#define RESET_BASE      0x60
#define DONE_BASE       0x70
#define ERROR_BASE      0x90

#define VGA_PIXEL       0x100
#define VGA_ENABLE      0x110
#define VGA_DONE        0x120

#define OP_IMG          0
#define OP_PES_ADDR     1
#define OP_PES_DATA     2
#define OP_BIAS         3
#define OP_BETA         4
#define OP_START        5
#define OP_STATUS       6
#define OP_ACTV         7
#define OP_CYCLES       8

#define READ_ONLY       0
#define SYS_READ        3
#define SYS_WRITE       4
#define SYS_OPEN        5
#define SYS_CLOSE       6
#define SYS_MUNMAP      91
#define SYS_MMAP2       192

#define MAP_SHARED      1
#define STDOUT          1

#define image_size      784
#define bias_size       256
#define beta_size       2560
#define pesos_size      200704

#define N_image         784
#define N_bias          128
#define N_beta          1280
#define N_pesos         100352

#define image_file  "/bin/img.bin"
#define bias_file   "/bin/b_q.bin"
#define beta_file   "/bin/beta_q.bin"
#define pesos_file  "/bin/W_in_q.bin"

#endif