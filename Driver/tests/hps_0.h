#pragma once

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

#define LW_BRIDGE_BASE  0xFF200000
#define LW_BRIDGE_SPAN  0x00005000

/**
 * Offsets HPS
 */
#define INST_BASE       0x20
#define OUT_BASE        0x30
#define ENABLE_BASE     0x40
#define BUSY_BASE       0x50
#define RESET_BASE      0x60
#define DONE_BASE       0x70

/**
 * OPCODES
 */
#define OP_IMG          0x00
#define OP_PES_ADDR     0x01
#define OP_PES_DATA     0x02
#define OP_BIAS         0x03
#define OP_BETA         0x04
#define OP_START        0x05
#define OP_STATUS       0x06

/**
 * SYSCALS ARMv7 Linux
 */
#define SYS_READ        3
#define SYS_WRITE       4
#define SYS_OPEN        5
#define SYS_CLOSE       6
#define SYS_MUNMAP      91
#define SYS_MMAP2       192

// open flags
#define O_RDWR          0x02
#define O_SYNC          0x101000

#define O_RDONLY        0x00
#define READ_MODE       0x00

// mmap flags
#define PROT_READ       1
#define MAP_SHARED      1
#define PROT_WRITE      2

// Outros
#define STDOUT          1
