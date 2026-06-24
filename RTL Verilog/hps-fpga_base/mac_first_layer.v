/***********************************************
MODULO ACUMULADOR DA REDE NEURAL
DESENVOLVIDA POR MAIKE DE OLIVEIRA NASCIMENTO MONITOR DA MATERIA DE SISTEMAS DIGITAIS
***********************************************/
module mac_first_layer(
	weigth_or_bias,
	one_or_pixel,
	clk,
	enable,
	rst,
	clear_acc,
	out_q4_12
);

    /***************************
    Entradas e saidas do modulo
    ***************************/
	input signed [15:0] weigth_or_bias;
    input [8:0] one_or_pixel;
    input clk, enable, rst, clear_acc;
    output signed [15:0] out_q4_12;
    

    /*****************************
    Fios e registradores de dados
    *****************************/
    // Pixel de 8 bits transformado em Q4.12
    wire signed [15:0] in_signed = {3'b000, one_or_pixel, 4'h0};
    // O produto de dois Q4.12 gera um Q8.24 (32 bits)
    wire signed [31:0] product_q8_24;
    wire signed [31:0] product_q_12;
    // Acumulador de 32 bits (Atua como um formato Q20.12 gigante, para evitar dar overflow na soma)
    reg signed [31:0] accumulator;
    
    assign product_q8_24 = in_signed * weigth_or_bias;
    assign product_q_12 = product_q8_24 >>> 12; 
    
    /*****************************************************
    Logica do sequencial do acumulador
    *****************************************************/
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            accumulator <= 32'sd0;
        end else if (clear_acc) begin
            accumulator <= 32'sd0;
        end else if (enable) begin
            // Agora estamos somando laranjas com laranjas!
            accumulator <= accumulator + product_q_12;
        end
    end
    
    // Saturação (Clipping) para encaixar os 32-bits de volta nos 16-bits de saída
    assign out_q4_12 = (accumulator > 32'sd32767)  ? 16'sd32767 :
                       (accumulator < -32'sd32768) ? -16'sd32768 :
                       accumulator[15:0]; 

endmodule