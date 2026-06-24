/*
Módulo: mac (Multiply-Accumulate)
Descrição:
    Este módulo implementa uma unidade MAC (Multiply-Accumulate), amplamente
    utilizada em arquiteturas de processamento digital de sinais e redes neurais.

    Sua função principal é realizar a multiplicação entre entradas (pixel e peso),
    seguida de um deslocamento aritmético (shift) para ajuste de escala, e a
    acumulação sucessiva dos resultados. Ao final do número definido de operações,
    um valor de bias é adicionado, e o resultado final é saturado para o intervalo
    de 16 bits com sinal.

    O módulo opera de forma sequencial, controlado por um sinal de início (start)
    e sinaliza a conclusão através do sinal 'done'.

Entradas:
    clk     : Sinal de clock do sistema.
    reset   : Reset assíncrono ativo em nível alto.
    start   : Sinal de início da operação MAC.

    pixel   : Valor de entrada (ex.: pixel da imagem ou beta).
    peso    : Peso correspondente ao pixel.
    bias    : Termo de bias adicionado ao final da acumulação.

    n_ops   : Número total de operações de multiplicação-acumulação.
    shift   : Quantidade de deslocamento aritmético à direita aplicado ao produto.

Saídas:
    addr    : Endereço/contador da operação atual.
    done    : Indica que o processamento foi concluído.
    saida   : Resultado final da operação MAC (com saturação em 16 bits).


*/
module mac (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,

    input  wire signed [15:0] pixel,
    input  wire signed [15:0] peso,
    input  wire signed [15:0] bias,

    input  wire [9:0]  n_ops,
    input  wire [4:0]  shift,

    output reg  [9:0]  addr,
    output reg         done,
    output reg  signed [15:0] saida
);

	integer mac_product;

	reg  signed [31:0] acumulador;
	wire signed [31:0] produto_full  = pixel * peso;
	wire signed [31:0] produto_shift = produto_full >>> shift;

	wire signed [31:0] soma_final = acumulador + produto_shift + bias;

	always @(posedge clk or posedge reset) begin
		 if (reset) begin
			  addr       <= 0;
			  acumulador <= 0;
			  saida      <= 0;
			  done       <= 0;

		 end else begin
			  if (done) begin
					if (!start) begin
						 done       <= 0;
						 acumulador <= 0;
						 addr       <= 0;
					end

			  end else if (start) begin
					acumulador <= acumulador + produto_shift;

					if (addr == n_ops - 1) begin

						 // saturação
						 if (soma_final > 32767)
							  saida <= 16'sh7FFF;
						 else if (soma_final < -32768)
							  saida <= 16'sh8000;
						 else
							  saida <= soma_final[15:0];

						 done <= 1;

					end else begin
						 addr <= addr + 1;
					end
			  end

		 end
	end

endmodule