/*
Módulo: argmax
Descrição:

    Este módulo implementa a operação de argmax, utilizada para determinar
    o índice associado ao maior valor dentre um conjunto de entradas.

    No contexto de redes neurais, o módulo recebe sequencialmente os valores
    de saída de cada classe e identifica aquela com maior valor,
    retornando seu índice como predição final.

    O funcionamento é incremental: a cada pulso de 'start', um novo valor
    (y_in) associado a um índice (idx) é comparado com o maior valor atual.
    Caso seja superior, o valor máximo e o índice correspondente são atualizados.

    Ao final da última classe (idx = 9), o módulo sinaliza a conclusão
    através do sinal 'done'.

Entradas:
    clk     : Clock do sistema.
    reset   : Reset assíncrono ativo em nível alto.
    start   : Habilita a comparação de entrada.

    y_in    : Valor de entrada (saída de um neurônio/classe).
    idx     : Índice associado ao valor de entrada.

Saídas:
    pred    : Índice da classe com maior valor (resultado do argmax).
    done    : Indica que todas as classes foram processadas.
*/
module argmax (
	input  wire        clk,
	input wire         reset,
	input wire         start,

	input  wire signed [15:0] y_in,    
	input  wire [3:0]  idx,            

	output reg  [3:0]  pred,           
	output reg         done
);

	reg signed [15:0] max_val;

	always @(posedge clk or posedge reset) begin
		if (reset) begin 
			pred<=0; 
			max_val<=16'sh8000; 
			done<=0; 
		end
		else if (start) begin
			if (y_in > max_val) begin 
				max_val <= y_in;
				pred <= idx; 
			end
			done <= (idx == 4'd9);
		end
	end
	
endmodule