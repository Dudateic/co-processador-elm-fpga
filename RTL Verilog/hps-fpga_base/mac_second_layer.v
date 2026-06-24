module mac_second_layer(
	data_register,
	data_beta,
	clk,
	enable,
	rst,
	clear_acc,
	out_q4_12
);

	input signed [15:0] data_register;
    input signed [15:0] data_beta;
    input clk, enable, rst, clear_acc;
    
    output signed [15:0] out_q4_12;
    
    // A multiplicação de dois números Q4.12 gera um produto Q8.24 (32 bits)
    wire signed [31:0] product_q8_24;
    assign product_q8_24 = data_beta * data_register;
    
    // CORREÇÃO: Deslocamento aritmético (>>>) de 12 casas para realinhar
    // Isso traz o produto de volta para o alinhamento de 12 casas fracionárias
    wire signed [31:0] product_q_12;
    assign product_q_12 = product_q8_24 >>> 12; 
    
    // Acumulador de 32 bits (Atua como um Q20.12, impossível estourar na soma de 128 ciclos)
    reg signed [31:0] accumulator;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            accumulator <= 32'sd0;
        end else if (clear_acc) begin
            accumulator <= 32'sd0;
        end else if (enable) begin
            // Agora somamos o valor com o ponto decimal no lugar certo!
            accumulator <= accumulator + product_q_12;
        end
    end
    
    // Saturação (Clipping) para proteger a conversão de volta para 16 bits (Q4.12)
    assign out_q4_12 = (accumulator > 32'sd32767)  ? 16'sd32767 :
                       (accumulator < -32'sd32768) ? -16'sd32768 :
                       accumulator[15:0];
    
endmodule