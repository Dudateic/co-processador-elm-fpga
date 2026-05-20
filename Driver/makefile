# ==========================================
# Configurações do Projeto
# ==========================================
# Nome do executável final
TARGET = acelerador_elm

# Compilador
# Nota: Se estiver compilando direto no Linux da placa, deixe gcc.
# Se estiver compilando no PC (cross-compiling), troque para arm-linux-gnueabihf-gcc
CC = gcc

# Diretórios
INCDIR = include
SRCDIR = src
ASMDIR = src/asm
OBJDIR = obj

# Flags de compilação
# -Wall e -Wextra ativam os avisos de erro
# -O2 otimiza o código para velocidade
# -I$(INCDIR) diz ao compilador onde achar os seus .h
CFLAGS = -Wall -Wextra -O2 -I$(INCDIR)

# ==========================================
# Mapeamento de Arquivos
# ==========================================
# Busca automaticamente todos os .c e .S nas pastas
C_SRCS = $(wildcard $(SRCDIR)/*.c)
ASM_SRCS = $(wildcard $(ASMDIR)/*.S)

# Transforma os nomes de .c e .S para .o dentro da pasta obj
C_OBJS = $(patsubst $(SRCDIR)/%.c, $(OBJDIR)/%.o, $(C_SRCS))
ASM_OBJS = $(patsubst $(ASMDIR)/%.S, $(OBJDIR)/asm/%.o, $(ASM_SRCS))

# Lista completa de objetos
OBJS = $(C_OBJS) $(ASM_OBJS)

# ==========================================
# Regras de Compilação
# ==========================================
# Regra padrão executada ao digitar apenas "make"
all: prepare $(TARGET)

# Linkagem final para gerar o executável
$(TARGET): $(OBJS)
	@echo "=> Linkando executavel: $@"
	$(CC) $(CFLAGS) -o $@ $^
	@echo "=> Build concluido com sucesso!"

# Regra para compilar arquivos .c
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@echo "=> Compilando C: $<"
	$(CC) $(CFLAGS) -c $< -o $@

# Regra para compilar arquivos Assembly (.S)
# O .S maiúsculo permite que o Assembly passe pelo pré-processador do C (para entender os includes)
$(OBJDIR)/asm/%.o: $(ASMDIR)/%.S
	@echo "=> Compilando Assembly: $<"
	$(CC) $(CFLAGS) -c $< -o $@

# Cria a estrutura de pastas para os objetos, se não existir
prepare:
	@mkdir -p $(OBJDIR)/asm

# Regra para limpar os arquivos compilados ("make clean")
clean:
	@echo "=> Limpando arquivos compilados..."
	rm -rf $(OBJDIR) $(TARGET)

# Diz ao Make que essas regras não são arquivos físicos
.PHONY: all prepare clean