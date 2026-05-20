# ==========================================
# Configurações do Projeto
# ==========================================
TARGET = acelerador_elm

# Padrão da indústria para cross-compilation. 
# Para PC: make CROSS_COMPILE=arm-linux-gnueabihf-
# Para Placa: make
CC = $(CROSS_COMPILE)gcc

# Flags de arquitetura ARM (DE1-SoC = Cortex-A9, ARMv7-A)
ARCH_FLAGS = -march=armv7-a -marm -mfloat-abi=hard -mfpu=neon

# ==========================================
# Modo de Compilação (Debug / Release)
# ==========================================
# Use 'make DEBUG=1' para compilar com símbolos de debug (ideal para gdb)
ifeq ($(DEBUG), 1)
    OPT_FLAGS = -O0 -g
    $(info => Compilando em modo DEBUG)
else
    OPT_FLAGS = -O2
    $(info => Compilando em modo RELEASE)
endif

# Diretórios
INCDIR  = include
SRCDIR  = src
ASMDIR  = src/asm
OBJDIR  = obj

# Flags de compilação 
# -MMD -MP: Gera ficheiros .d magicamente para rastrear alterações nos headers (.h)
CFLAGS  = -Wall -Wextra $(OPT_FLAGS) -I$(INCDIR) $(ARCH_FLAGS) -MMD -MP
ASFLAGS = -x assembler-with-cpp $(OPT_FLAGS) -I$(INCDIR) $(ARCH_FLAGS) -MMD -MP

# Flags exclusivas para o Linker (LDFLAGS)
LDFLAGS = -lm $(ARCH_FLAGS) -Wl,-z,noexecstack

# ==========================================
# Mapeamento de Arquivos
# ==========================================
C_SRCS   = $(wildcard $(SRCDIR)/*.c)
ASM_SRCS = $(wildcard $(ASMDIR)/*.S)

C_OBJS   = $(patsubst $(SRCDIR)/%.c,   $(OBJDIR)/%.o,     $(C_SRCS))
ASM_OBJS = $(patsubst $(ASMDIR)/%.S,   $(OBJDIR)/asm/%.o, $(ASM_SRCS))

OBJS = $(C_OBJS) $(ASM_OBJS)
DEPS = $(OBJS:.o=.d) # Lista de todos os ficheiros de dependência .d gerados

# ==========================================
# Regras de Compilação
# ==========================================
all: $(TARGET)

$(TARGET): $(OBJS)
	@echo "=> Linkando executavel: $@"
	$(CC) -o $@ $^ $(LDFLAGS)
	@echo "=> Build concluido com sucesso!"

# Compilar .c
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(dir $@) 
	@echo "=> Compilando C: $<"
	$(CC) $(CFLAGS) -c $< -o $@

# Compilar .S
$(OBJDIR)/asm/%.o: $(ASMDIR)/%.S
	@mkdir -p $(dir $@)
	@echo "=> Compilando Assembly: $<"
	$(CC) $(ASFLAGS) -c $< -o $@

clean:
	@echo "=> Limpando arquivos compilados..."
	rm -rf $(OBJDIR) $(TARGET)

.PHONY: all clean

# Inclui os ficheiros de dependência (.d) gerados na compilação anterior.
# O travessão (-) na frente oculta o erro na primeira vez que se corre o make, 
# pois os ficheiros .d ainda não existem.
-include $(DEPS)