# ==========================================
# Configurações do Projeto
# ==========================================
TARGET = acelerador_elm

# Para compilar no PC (cross-compile), use:
#   make CC=arm-linux-gnueabihf-gcc
# Para compilar direto na placa, deixe gcc:
CC = gcc

# Flags de arquitetura ARM (DE1-SoC = Cortex-A9, ARMv7-A)
ARCH_FLAGS = -march=armv7-a -marm -mfloat-abi=hard -mfpu=neon

# Diretórios
INCDIR  = include
SRCDIR  = src
ASMDIR  = src/asm
OBJDIR  = obj

# Flags de compilação C
CFLAGS  = -Wall -Wextra -O2 -I$(INCDIR) $(ARCH_FLAGS)

# Flags específicas para Assembly
# -x assembler-with-cpp: força o pré-processador C no .S (para os #include e #define do hps_0.h)
ASFLAGS = -x assembler-with-cpp -I$(INCDIR) $(ARCH_FLAGS)

# ==========================================
# Mapeamento de Arquivos
# ==========================================
C_SRCS   = $(wildcard $(SRCDIR)/*.c)
ASM_SRCS = $(wildcard $(ASMDIR)/*.S)

C_OBJS   = $(patsubst $(SRCDIR)/%.c,   $(OBJDIR)/%.o,     $(C_SRCS))
ASM_OBJS = $(patsubst $(ASMDIR)/%.S,   $(OBJDIR)/asm/%.o, $(ASM_SRCS))

OBJS = $(C_OBJS) $(ASM_OBJS)

# ==========================================
# Regras de Compilação
# ==========================================
all: prepare $(TARGET)

$(TARGET): $(OBJS)
	@echo "=> Linkando executavel: $@"
	$(CC) $(ARCH_FLAGS) -o $@ $^ -lm
	@echo "=> Build concluido com sucesso!"

# Compilar .c
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@echo "=> Compilando C: $<"
	$(CC) $(CFLAGS) -c $< -o $@

# Compilar .S — usa ASFLAGS em vez de CFLAGS
$(OBJDIR)/asm/%.o: $(ASMDIR)/%.S
	@echo "=> Compilando Assembly: $<"
	$(CC) $(ASFLAGS) -c $< -o $@

prepare:
	@mkdir -p $(OBJDIR)/asm

clean:
	@echo "=> Limpando arquivos compilados..."
	rm -rf $(OBJDIR) $(TARGET)

.PHONY: all prepare clean